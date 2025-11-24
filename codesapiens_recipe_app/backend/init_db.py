#!/usr/bin/env python3

import os
from app import create_app
from db import db
from models import User, Favorite, Progress, Activity

def init_database():
    """Initialize the database with all tables."""
    app = create_app()
    with app.app_context():
        
        
        # Create all tables
        db.create_all()
        print("Database initialized successfully!")
        print("Tables created: users, favorites, progress, activities")
        print("\nNote: Activities table is designed to persist forever.")
        print("Activities are never deleted, only added.")

if __name__ == '__main__':
    init_database()

