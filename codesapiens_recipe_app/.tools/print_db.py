import sqlite3, json, sys

db = 'codesapiens_app.db'

try:
    conn = sqlite3.connect(db)
    cur = conn.cursor()
    users = []
    try:
        rows = cur.execute('SELECT email, name, password FROM users').fetchall()
        for r in rows:
            users.append({'email': r[0], 'name': r[1], 'password': r[2]})
    except Exception as e:
        users = []

    favs = []
    try:
        rows = cur.execute('SELECT id FROM favorites').fetchall()
        favs = [r[0] for r in rows]
    except Exception as e:
        favs = []

    print('USERS_JSON:')
    print(json.dumps(users, indent=2))
    print('\nFAVORITES_JSON:')
    print(json.dumps(favs, indent=2))

except Exception as e:
    print('ERROR:', e)
    sys.exit(1)
finally:
    try:
        conn.close()
    except:
        pass
