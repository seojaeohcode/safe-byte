"""User-owned family profiles, shopping sessions, and expiring device capabilities."""
import hashlib
import json
import secrets
import uuid
from datetime import timedelta

from app.core.database import utc_now, json_dumps, json_loads
from app.services.profile_tokens import normalize_profiles


class WorkspaceError(ValueError):
    pass


class Workspace:
    def __init__(self, db):
        self.db = db
        with db.connect() as c:
            c.executescript("""
            CREATE TABLE IF NOT EXISTS family_profiles (
              id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(user_id),
              name TEXT NOT NULL, profiles_json TEXT NOT NULL, language TEXT NOT NULL);
            CREATE TABLE IF NOT EXISTS shopping_carts (
              id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(user_id),
              name TEXT NOT NULL, profiles_json TEXT NOT NULL, language TEXT NOT NULL,
              status TEXT NOT NULL DEFAULT 'active', created_at TEXT NOT NULL);
            CREATE TABLE IF NOT EXISTS cart_items (
              id TEXT PRIMARY KEY, cart_id TEXT NOT NULL REFERENCES shopping_carts(id),
              request_id TEXT NOT NULL REFERENCES analysis_requests(request_id),
              name TEXT NOT NULL, quantity INTEGER NOT NULL CHECK(quantity>0),
              UNIQUE(cart_id, request_id));
            CREATE TABLE IF NOT EXISTS device_pairings (
              code_hash TEXT PRIMARY KEY, cart_id TEXT NOT NULL REFERENCES shopping_carts(id),
              expires_at TEXT NOT NULL, token_hash TEXT UNIQUE, token_expires_at TEXT);
            CREATE TABLE IF NOT EXISTS saved_products (
              id TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(user_id),
              name TEXT NOT NULL, category TEXT NOT NULL, label_text TEXT NOT NULL,
              source_request_id TEXT NOT NULL, created_at TEXT NOT NULL);
            CREATE INDEX IF NOT EXISTS family_owner ON family_profiles(user_id);
            CREATE INDEX IF NOT EXISTS carts_owner ON shopping_carts(user_id);
            """)
            if 'nutrition_json' not in [r[1] for r in c.execute('PRAGMA table_info(cart_items)')]:
                c.execute('ALTER TABLE cart_items ADD COLUMN nutrition_json TEXT')

    @staticmethod
    def decode(row):
        result = dict(row)
        if "profiles_json" in result:
            result["profiles"] = json_loads(result.pop("profiles_json"), [])
        return result

    def families(self, user_id):
        with self.db.connect() as c:
            return [self.decode(r) for r in c.execute("SELECT * FROM family_profiles WHERE user_id=? ORDER BY name", (user_id,))]

    def save_family(self, user_id, name, profiles, language, profile_id=None):
        profile_id = profile_id or str(uuid.uuid4())
        with self.db.connect() as c:
            existing = c.execute("SELECT user_id FROM family_profiles WHERE id=?", (profile_id,)).fetchone()
            if existing and existing[0] != user_id:
                raise WorkspaceError("Profile not found")
            if not existing and c.execute("SELECT count(*) FROM family_profiles WHERE user_id=?", (user_id,)).fetchone()[0] >= 20:
                raise WorkspaceError("Maximum 20 family profiles")
            c.execute("INSERT INTO family_profiles VALUES (?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET name=excluded.name, profiles_json=excluded.profiles_json, language=excluded.language", (profile_id, user_id, name, json_dumps(profiles), language))
        return {"id": profile_id, "name": name, "profiles": profiles, "language": language}

    def delete_family(self, user_id, profile_id):
        with self.db.connect() as c:
            c.execute("DELETE FROM family_profiles WHERE id=? AND user_id=?", (profile_id, user_id))

    def cart(self, user_id, cart_id):
        with self.db.connect() as c:
            row = c.execute("SELECT * FROM shopping_carts WHERE id=? AND user_id=?", (cart_id, user_id)).fetchone()
            if not row:
                raise WorkspaceError("Cart not found")
            return self.decode(row)

    def create_cart(self, user_id, name, profiles, language):
        cart_id = str(uuid.uuid4())
        with self.db.connect() as c:
            c.execute("INSERT INTO shopping_carts(id,user_id,name,profiles_json,language,created_at) VALUES(?,?,?,?,?,?)", (cart_id,user_id,name,json_dumps(profiles),language,utc_now().isoformat()))
        return self.cart(user_id, cart_id)

    def carts(self, user_id):
        with self.db.connect() as c:
            return [self.decode(r) for r in c.execute("SELECT * FROM shopping_carts WHERE user_id=? ORDER BY created_at DESC LIMIT 100", (user_id,))]

    def add_item(self, user_id, cart_id, request_id, name, quantity):
        cart = self.cart(user_id, cart_id)
        if cart["status"] != "active" or not self.db.owns_analysis(request_id, user_id):
            raise WorkspaceError("Cart is closed or analysis not found")
        result = self.db.get_analysis_response(request_id)
        if result.get("status") != "completed" or set(result["profiles"]) != set(cart["profiles"]):
            raise WorkspaceError("Analyze using this cart's dietary criteria before adding")
        with self.db.connect() as c:
            c.execute('BEGIN IMMEDIATE')
            if c.execute("SELECT status FROM shopping_carts WHERE id=?", (cart_id,)).fetchone()[0] != 'active':
                raise WorkspaceError('Cart is closed')
            c.execute("INSERT INTO cart_items(id,cart_id,request_id,name,quantity) VALUES(?,?,?,?,?) ON CONFLICT(cart_id,request_id) DO UPDATE SET quantity=excluded.quantity,name=excluded.name", (str(uuid.uuid4()),cart_id,request_id,name,quantity))
        return self.report(user_id, cart_id)

    def confirm_nutrition(self, user_id, cart_id, item_id, values):
        self.cart(user_id, cart_id)
        with self.db.connect() as c:
            c.execute('BEGIN IMMEDIATE')
            if c.execute('SELECT status FROM shopping_carts WHERE id=?', (cart_id,)).fetchone()[0] != 'active':
                raise WorkspaceError('Cart is closed')
            changed = c.execute('UPDATE cart_items SET nutrition_json=? WHERE id=? AND cart_id=?',
                                (json_dumps(values), item_id, cart_id)).rowcount
            if not changed:
                raise WorkspaceError('Item not found')
        return self.report(user_id, cart_id)

    def remove_item(self, user_id, cart_id, item_id):
        cart = self.cart(user_id, cart_id)
        if cart["status"] != "active":
            raise WorkspaceError("Cart is closed")
        with self.db.connect() as c:
            c.execute("DELETE FROM cart_items WHERE id=? AND cart_id=?", (item_id, cart_id))

    def report(self, user_id, cart_id):
        cart = self.cart(user_id, cart_id)
        with self.db.connect() as c:
            rows = c.execute("SELECT i.*,a.response_json FROM cart_items i JOIN analysis_requests a ON a.request_id=i.request_id WHERE i.cart_id=?", (cart_id,)).fetchall()
        items, counts = [], {"SAFE": 0, "CAUTION": 0, "DANGER": 0}
        totals, covered = {}, {}
        for row in rows:
            item = dict(row)
            result = json_loads(item.pop("response_json"), {})
            item["risk"] = result["risk"]
            item["quality"] = result.get("quality", {})
            item['nutrition_candidate'] = result.get('nutrition', {})
            item['nutrition'] = json_loads(item.pop('nutrition_json'), {})
            for key, value in item['nutrition'].items():
                totals[key] = round(totals.get(key, 0) + value * item['quantity'], 3)
                covered[key] = covered.get(key, 0) + item['quantity']
            counts[item["risk"]["final_level"]] += item["quantity"]
            items.append(item)
        level = "DANGER" if counts["DANGER"] else "CAUTION" if counts["CAUTION"] else "SAFE" if items else "EMPTY"
        return {"cart": cart, "items": items, "counts": counts, "final_level": level,
                "total_quantity": sum(counts.values()), "nutrition": {'status': 'confirmed_partial' if totals else 'not_available',
                'totals': totals, 'covered_quantity': covered,
                'note': '사용자가 확인한 상품 전체 기준 × 수량입니다. 누락값은 0으로 간주하지 않으며 실제 섭취량과 다릅니다.'}}

    def close_cart(self, user_id, cart_id):
        self.cart(user_id, cart_id)
        with self.db.connect() as c:
            c.execute("UPDATE shopping_carts SET status='closed' WHERE id=?", (cart_id,))
            c.execute("DELETE FROM device_pairings WHERE cart_id=?", (cart_id,))
        return self.report(user_id, cart_id)

    def pairing(self, user_id, cart_id):
        if self.cart(user_id, cart_id)["status"] != "active":
            raise WorkspaceError("Cart is closed")
        code = secrets.token_urlsafe(18)
        expires = (utc_now() + timedelta(minutes=5)).isoformat()
        with self.db.connect() as c:
            c.execute("DELETE FROM device_pairings WHERE cart_id=?", (cart_id,))
            c.execute("INSERT INTO device_pairings(code_hash,cart_id,expires_at) VALUES(?,?,?)", (self.digest(code),cart_id,expires))
        return {"code": code, "expires_at": expires, "cart_id": cart_id}

    def redeem(self, code):
        token = secrets.token_urlsafe(32)
        expires = (utc_now() + timedelta(hours=4)).isoformat()
        with self.db.connect() as c:
            c.execute("BEGIN IMMEDIATE")
            row = c.execute("SELECT p.cart_id FROM device_pairings p JOIN shopping_carts s ON s.id=p.cart_id WHERE code_hash=? AND expires_at>? AND token_hash IS NULL AND s.status='active'", (self.digest(code),utc_now().isoformat())).fetchone()
            if not row:
                raise WorkspaceError("Pairing code is invalid or expired")
            c.execute("UPDATE device_pairings SET token_hash=?,token_expires_at=? WHERE code_hash=?", (self.digest(token),expires,self.digest(code)))
        return {"token": token, "expires_at": expires, "cart_id": row[0]}

    def device_cart(self, token):
        with self.db.connect() as c:
            row = c.execute("SELECT s.* FROM device_pairings p JOIN shopping_carts s ON s.id=p.cart_id WHERE p.token_hash=? AND p.token_expires_at>? AND s.status='active'", (self.digest(token),utc_now().isoformat())).fetchone()
        if not row:
            raise WorkspaceError("Device session expired or revoked")
        return self.decode(row)

    @staticmethod
    def digest(value):
        return hashlib.sha256(value.encode()).hexdigest()

    def history(self, user_id):
        with self.db.connect() as c:
            return [dict(r) for r in c.execute("SELECT request_id,source_name,status,final_level,created_at FROM analysis_requests WHERE user_id=? ORDER BY created_at DESC LIMIT 100", (user_id,))]

    def save_product(self, user_id, request_id, name, category):
        if not self.db.owns_analysis(request_id, user_id):
            raise WorkspaceError("Analysis not found")
        result = self.db.get_analysis_response(request_id)
        if result.get("status") != "completed" or result.get("quality", {}).get("needs_review"):
            raise WorkspaceError("A readable ingredient label is required")
        product_id = str(uuid.uuid4())
        with self.db.connect() as c:
            c.execute("INSERT INTO saved_products VALUES(?,?,?,?,?,?,?)", (product_id,user_id,name,category,result["ocr"]["corrected_text"],request_id,utc_now().isoformat()))
        return {"id": product_id, "name": name, "category": category}

    def products(self, user_id):
        with self.db.connect() as c:
            return [dict(r) for r in c.execute(
                "SELECT id,name,category,source_request_id,created_at FROM saved_products WHERE user_id=? ORDER BY created_at DESC LIMIT 200", (user_id,))]

    def delete_product(self, user_id, product_id):
        with self.db.connect() as c:
            if c.execute("DELETE FROM saved_products WHERE id=? AND user_id=?", (product_id, user_id)).rowcount != 1:
                raise WorkspaceError("Product not found")

    def alternatives(self, user_id, profiles, category, rules):
        with self.db.connect() as c:
            rows = c.execute("SELECT * FROM saved_products WHERE user_id=? AND category=? ORDER BY created_at DESC LIMIT 200", (user_id,category)).fetchall()
        candidates = []
        for row in rows:
            risk = rules.detect(row["label_text"], profiles)
            if risk["final_level"] == "SAFE":
                candidates.append({"id":row["id"],"name":row["name"],"category":row["category"],"source_request_id":row["source_request_id"],"risk":risk})
        return {"products":candidates[:20], "basis":"saved_label_rules", "note":"저장된 라벨 기준 후보입니다. 구매 시 최신 라벨을 다시 확인하세요."}
