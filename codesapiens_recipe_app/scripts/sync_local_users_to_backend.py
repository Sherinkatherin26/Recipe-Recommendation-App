import sqlite3
import requests

# CONFIGURE THESE
SQLITE_DB_PATH = '../codesapiens_app.db'  # Adjust path if needed
BACKEND_URL = 'http://127.0.0.1:5000/signup'  # Change to your backend URL

# Read users from local SQLite DB
def get_local_users(db_path):
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.execute('SELECT name, email, password FROM users')
    users = cursor.fetchall()
    conn.close()
    return users

# Register user to backend
def register_user_to_backend(name, email, password):
    data = {'name': name, 'email': email, 'password': password}
    try:
        resp = requests.post(BACKEND_URL, json=data)
        if resp.status_code == 200 or resp.status_code == 201:
            print(f'Success: {email}')
        elif 'already exists' in resp.text:
            print(f'Exists: {email}')
        else:
            print(f'Error for {email}: {resp.text}')
    except Exception as e:
        print(f'Failed for {email}: {e}')

if __name__ == '__main__':
    users = get_local_users(SQLITE_DB_PATH)
    print(f'Found {len(users)} users in local DB.')
    for name, email, password in users:
        register_user_to_backend(name, email, password)
    print('Sync complete.')
