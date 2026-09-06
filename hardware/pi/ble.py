"""BLE only transports a short-lived, single-use pairing code, never user profiles."""
SERVICE = '76c10001-249b-4e40-9c5d-a0f6b80c10a1'
CHARACTERISTIC = '76c10002-249b-4e40-9c5d-a0f6b80c10a1'


def serve(on_code):
    from bluezero import adapter, peripheral
    buffer = bytearray()
    def write(value, options):
        nonlocal buffer
        buffer.extend(bytes(value))
        if len(buffer)>128:
            buffer.clear()
            return
        if b'\n' in buffer:
            value=bytes(buffer).split(b'\n')[0]
            buffer.clear()
            try:
                code=value.decode('ascii').strip()
                if 16<=len(code)<=100: on_code(code)
            except UnicodeDecodeError: pass
    device=peripheral.Peripheral(list(adapter.Adapter.available())[0].address,local_name='SafeByte Cart')
    device.add_service(srv_id=1,uuid=SERVICE,primary=True)
    device.add_characteristic(srv_id=1,chr_id=1,uuid=CHARACTERISTIC,value=[],notifying=False,flags=['write'],write_callback=write)
    device.publish()
