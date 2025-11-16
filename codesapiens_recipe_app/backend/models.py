from datetime import datetime
from werkzeug.security import generate_password_hash, check_password_hash
from db import db


class User(db.Model):
    __tablename__ = 'users'
    email = db.Column(db.String, primary_key=True)
    name = db.Column(db.String)
    password_hash = db.Column(db.String)

    def set_password(self, pw: str):
        self.password_hash = generate_password_hash(pw)

    def check_password(self, pw: str) -> bool:
        return check_password_hash(self.password_hash or '', pw)


class Favorite(db.Model):
    __tablename__ = 'favorites'
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    user_email = db.Column(db.String, db.ForeignKey('users.email'))
    recipe_id = db.Column(db.String)


class Progress(db.Model):
    __tablename__ = 'progress'
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    user_email = db.Column(db.String, db.ForeignKey('users.email'))
    recipe_id = db.Column(db.String)
    status = db.Column(db.String)
    position = db.Column(db.Integer, default=0)
    timestamp = db.Column(db.Integer, default=lambda: int(datetime.utcnow().timestamp() * 1000))


class Activity(db.Model):
    __tablename__ = 'activities'
    id = db.Column(db.Integer, primary_key=True, autoincrement=True)
    user_email = db.Column(db.String, db.ForeignKey('users.email'))
    activity = db.Column(db.String)
    timestamp = db.Column(db.Integer, default=lambda: int(datetime.utcnow().timestamp() * 1000))
