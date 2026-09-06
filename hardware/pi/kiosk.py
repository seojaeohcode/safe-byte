"""Raspberry Pi LCD kiosk with USB serial trigger and opt-in motion capture."""
import argparse
import io
import queue
import threading
import time
import tkinter as tk
from concurrent.futures import ThreadPoolExecutor

import cv2
from PIL import Image, ImageTk
from client import CartClient


class Kiosk:
    def __init__(self, args):
        self.args, self.client = args, CartClient(args.api)
        self.root = tk.Tk()
        self.root.title('Safe-Byte Cart')
        self.root.geometry('1024x600')
        self.root.configure(bg='#191b20')
        self.messages = queue.Queue()
        self.pool = ThreadPoolExecutor(max_workers=1)
        self.busy = False
        self.generation = 0
        self.frame = None
        self.previous = None
        self.motion_seen = False
        self.stable_since = time.monotonic()
        self.last_scan = 0
        self.last_check = 0
        self.camera = None
        self.picamera = None
        if args.picamera:
            from picamera2 import Picamera2
            self.picamera = Picamera2()
            self.picamera.configure(self.picamera.create_preview_configuration(main={'size':(1280,720),'format':'RGB888'}))
            self.picamera.start()
        else:
            self.camera = cv2.VideoCapture(args.camera)
        self.serial = None
        if args.serial:
            import serial
            self.serial = serial.Serial(args.serial,115200,timeout=0)
        self.title = tk.Label(self.root,text='앱에서 카트를 연결하세요 / Pair from app',fg='white',bg='#191b20',font=('sans',22))
        self.title.pack()
        self.preview = tk.Label(self.root,bg='#191b20')
        self.preview.pack()
        self.code = tk.Entry(self.root,width=36,font=('sans',16))
        self.code.pack()
        tk.Button(self.root,text='연결 / Pair',command=lambda:self.pair(self.code.get().strip())).pack()
        tk.Button(self.root,text='라벨 촬영 / Scan label',command=self.scan).pack()
        tk.Button(self.root,text='개인정보 지우기 / Clear session',command=self.clear).pack()
        self.root.protocol('WM_DELETE_WINDOW',self.close)
        if args.ble:
            from ble import serve
            threading.Thread(target=serve,args=(lambda code:self.messages.put(('pair',code)),),daemon=True).start()
        self.root.after(50,self.tick)

    def submit(self, fn, kind):
        if self.busy: return
        self.busy = True
        generation = self.generation
        def work():
            try: self.messages.put((kind,fn(),generation))
            except Exception as e: self.messages.put(('error',type(e).__name__,generation))
        self.pool.submit(work)

    def pair(self, code):
        if len(code)<16: return
        self.submit(lambda:self.client.pair(code),'paired')
        self.code.delete(0,tk.END)

    def signal(self, state):
        if self.serial:
            self.serial.write((state+'\n').encode('ascii'))

    def scan(self):
        if self.busy or self.frame is None or not self.client.token: return
        # Crop a fixed guide region before upload; the backend returns coordinates on its own preview.
        h,w=self.frame.shape[:2]
        roi=self.frame[int(h*.1):int(h*.9),int(w*.1):int(w*.9)]
        ok,jpeg=cv2.imencode('.jpg',roi,[cv2.IMWRITE_JPEG_QUALITY,90])
        if not ok: return
        self.last_scan=time.monotonic()
        self.signal('BUSY')
        self.title.config(text='분석 중 / Analyzing',fg='#87a9ff')
        self.submit(lambda:self.client.analyze(jpeg.tobytes()),'result')

    def clear(self):
        self.generation += 1
        self.client.clear()
        self.title.config(text='앱에서 카트를 연결하세요 / Pair from app',fg='white')
        self.signal('IDLE')

    def tick(self):
        now=time.monotonic()
        if self.picamera:
            frame=self.picamera.capture_array()
            ok=True
        else:
            ok,frame=self.camera.read()
        if ok:
            self.frame=frame
            small=cv2.resize(cv2.cvtColor(frame,cv2.COLOR_BGR2GRAY),(160,90))
            if self.previous is not None:
                diff=float(cv2.absdiff(small,self.previous).mean())
                if diff>12:
                    self.motion_seen=True; self.stable_since=now
                if self.args.auto and self.motion_seen and now-self.stable_since>1.2 and now-self.last_scan>8:
                    self.scan(); self.motion_seen=False
            self.previous=small
            shown=cv2.resize(frame,(640,360))
            cv2.rectangle(shown,(64,36),(576,324),(198,226,45),2)
            self.photo=ImageTk.PhotoImage(Image.fromarray(cv2.cvtColor(shown,cv2.COLOR_BGR2RGB)))
            self.preview.config(image=self.photo)
        if self.serial and self.serial.in_waiting:
            if b'SCAN' in self.serial.read(self.serial.in_waiting): self.scan()
        while not self.messages.empty():
            message=self.messages.get()
            kind,data=message[:2]
            if kind=='pair': self.pair(data); continue
            self.busy=False
            if message[2] != self.generation:
                continue
            if kind=='result':
                level=data['risk']['final_level']
                self.title.config(text=level+' · '+data.get('translation',{}).get('summary',data['risk']['summary']),fg={'SAFE':'#30d989','CAUTION':'#ffcf66','DANGER':'#ff6f61'}[level],wraplength=980)
                self.signal(level)
            elif kind=='paired': self.title.config(text='연결 완료 / Ready to scan',fg='#2de2c6')
            elif kind=='error':
                self.title.config(text='연결 또는 라벨 확인 필요 / Check connection and label',fg='#ffcf66'); self.signal('ERROR')
            elif kind=='checked' and not self.client.token: self.clear()
        if not self.busy and self.client.token and now-self.last_check>10:
            self.last_check=now
            self.submit(self.client.check,'checked')
        if not self.client.token and not self.busy: self.signal('IDLE')
        self.root.after(80,self.tick)

    def close(self):
        if self.camera:self.camera.release()
        if self.picamera:self.picamera.stop()
        if self.serial:self.serial.close()
        self.pool.shutdown(wait=False,cancel_futures=True)
        self.client.clear()
        self.root.destroy()


if __name__=='__main__':
    p=argparse.ArgumentParser()
    p.add_argument('--api',required=True)
    p.add_argument('--camera',type=int,default=0)
    p.add_argument('--picamera',action='store_true')
    p.add_argument('--serial')
    p.add_argument('--auto',action='store_true')
    p.add_argument('--ble',action='store_true')
    kiosk=Kiosk(p.parse_args())
    kiosk.root.mainloop()
