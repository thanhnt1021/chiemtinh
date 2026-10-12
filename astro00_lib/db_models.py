# astro00_lib/db_models.py
from sqlalchemy import create_engine, Column, Integer, String, Float, Boolean, Text, ForeignKey, desc
from sqlalchemy.orm import sessionmaker, declarative_base, relationship
from sqlalchemy.dialects.postgresql import JSONB
from datetime import datetime
import hashlib

# --- CẤU HÌNH POSTGRESQL ---
DB_USER = "nguydev"
DB_PASS = "***DA-GO***"
DB_HOST = "localhost"
DB_PORT = "5432"
DB_NAME = "astro"

DATABASE_URL = f"postgresql://{DB_USER}:{DB_PASS}@{DB_HOST}:{DB_PORT}/{DB_NAME}"

Base = declarative_base()
engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

class User(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True, index=True, nullable=False)
    password_hash = Column(String, nullable=False)
    user_uid = Column(String, unique=True, nullable=False)
    created_at = Column(String, default=lambda: datetime.now().isoformat())

class Profile(Base):
    __tablename__ = "profiles"
    id = Column(Integer, primary_key=True, index=True)
    user_uid = Column(String, ForeignKey("users.user_uid"), nullable=False)
    name = Column(String, nullable=False)
    gender = Column(String)
    data = Column(JSONB, nullable=False)
    created_at = Column(String, default=lambda: datetime.now().isoformat())

def init_db():
    Base.metadata.create_all(bind=engine)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def hash_password(password):
    import hashlib
    return hashlib.sha256(password.encode()).hexdigest()

def check_password_strength(password):
    return len(password) >= 6

def load_users():
    db = SessionLocal()
    users_db = db.query(User).all()
    db.close()
    return {u.username: {"username": u.username, "password": u.password_hash, "user_id": u.user_uid} for u in users_db}

def save_users(data_dict):
    db = SessionLocal()
    for uname, udata in data_dict.items():
        exists = db.query(User).filter(User.username == uname).first()
        if not exists:
            new_user = User(
                username=udata["username"],
                password_hash=udata["password"],
                user_uid=udata["user_id"]
            )
            db.add(new_user)
    db.commit()
    db.close()

def change_password(username, old_pass_raw, new_pass_raw):
    db = SessionLocal()
    user = db.query(User).filter(User.username == username).first()
    if not user:
        db.close()
        return False, "User not found"
    old_hash = hash_password(old_pass_raw)
    if user.password_hash != old_hash:
        db.close()
        return False, "Mật khẩu cũ không đúng"
    user.password_hash = hash_password(new_pass_raw)
    db.commit()
    db.close()
    return True, "Đổi mật khẩu thành công"

def get_all_users_admin():
    db = SessionLocal()
    users_db = db.query(User).order_by(desc(User.id)).all()
    res = []
    for u in users_db:
        p_count = db.query(Profile).filter(Profile.user_uid == u.user_uid).count()
        res.append({
            "id": u.id,
            "username": u.username,
            "user_uid": u.user_uid,
            "created_at": u.created_at,
            "profile_count": p_count
        })
    db.close()
    return res

def delete_user_admin(user_id_db):
    db = SessionLocal()
    user = db.query(User).filter(User.id == user_id_db).first()
    if user:
        db.query(Profile).filter(Profile.user_uid == user.user_uid).delete()
        db.delete(user)
        db.commit()
        db.close()
        return True
    db.close()
    return False

def get_all_profiles_admin():
    db = SessionLocal()
    results = db.query(Profile, User.username).join(User, Profile.user_uid == User.user_uid).order_by(desc(Profile.id)).all()
    data = []
    for p, owner in results:
        data.append({
            "id": p.id,
            "owner": owner,
            "name": p.name,
            "dob": p.data.get("dob"),
            "created_at": p.created_at
        })
    db.close()
    return data

def load_profiles(user_id=None):
    """
    Hàm load hồ sơ kèm theo cơ chế Auto-healing (Vá dữ liệu).
    Đảm bảo dữ liệu từ v14 cũ luôn có đủ trường để v15.2 chạy không lỗi.
    """
    db = SessionLocal()
    if user_id:
        profiles_db = db.query(Profile).filter(Profile.user_uid == user_id).all()
    else:
        profiles_db = db.query(Profile).all()
    db.close()

    results = []
    for p in profiles_db:
        p_data = p.data
        loc_data = p_data.get("loc", {})
        
        # Vá dữ liệu nếu thiếu trường của v15.2
        if "country_code" not in loc_data:
            loc_data["country_code"] = "vn"
        if "lat" not in loc_data: loc_data["lat"] = 21.02
        if "lon" not in loc_data: loc_data["lon"] = 105.85
        if "tz" not in loc_data: loc_data["tz"] = "Asia/Ho_Chi_Minh"
        if "address" not in loc_data: loc_data["address"] = "Hanoi, Vietnam"

        full_p = {
            "user_id": p.user_uid,
            "name": p.name,
            "gender": p.gender,
            "dob": p_data.get("dob"),
            "tob": p_data.get("tob"),
            "loc": loc_data,
            "tz_offset": p_data.get("tz_offset")
        }
        results.append(full_p)
    return results

def save_profile(profile_data):
    db = SessionLocal()
    data_json = {
        "dob": profile_data["dob"],
        "tob": profile_data["tob"],
        "loc": profile_data["loc"]
    }
    if "tz_offset" in profile_data and profile_data["tz_offset"] is not None:
        data_json["tz_offset"] = profile_data["tz_offset"]
    new_profile = Profile(
        user_uid=profile_data["user_id"],
        name=profile_data["name"],
        gender=profile_data["gender"],
        data=data_json
    )
    db.add(new_profile)
    db.commit()
    db.close()

def delete_profile(user_id, profile_name):
    db = SessionLocal()
    db.query(Profile).filter(Profile.user_uid == user_id, Profile.name == profile_name).delete()
    db.commit()
    db.close()

def update_profile(user_id, old_name, new_data):
    db = SessionLocal()
    profile = db.query(Profile).filter(Profile.user_uid == user_id, Profile.name == old_name).first()
    if profile:
        profile.name = new_data["name"]
        profile.gender = new_data["gender"]
        data_json = {
            "dob": new_data["dob"],
            "tob": new_data["tob"],
            "loc": new_data["loc"]
        }
        if "tz_offset" in new_data and new_data["tz_offset"] is not None:
            data_json["tz_offset"] = new_data["tz_offset"]
        profile.data = data_json
        db.commit()
        db.close()
        return True
    db.close()
    return False

def reset_user_password(username, new_pass_raw):
    db = SessionLocal()
    user = db.query(User).filter(User.username == username).first()
    if not user:
        db.close()
        return False
    user.password_hash = hash_password(new_pass_raw)
    db.commit()
    db.close()
    return True
