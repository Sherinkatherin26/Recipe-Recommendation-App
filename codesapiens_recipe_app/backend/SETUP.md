# Backend Setup Guide

## Quick Start

1. **Install Dependencies**
   ```bash
   cd codesapiens_recipe_app/backend
   pip install -r requirements.txt
   ```

2. **Run the Server**
   ```bash
   python app.py
   ```
   The server will start on `http://0.0.0.0:5000`

3. **Database**
   - Database is automatically created on first run
   - SQLite database file: `app.db` (in backend directory)
   - To reset database: Run `python init_db.py` (WARNING: deletes all data)

## Database Schema

### Users Table
- `email` (PRIMARY KEY): User email address
- `name`: User display name
- `password_hash`: Hashed password

### Favorites Table
- `id` (PRIMARY KEY): Auto-increment ID
- `user_email` (FOREIGN KEY): References users.email
- `recipe_id`: Recipe identifier

### Progress Table
- `id` (PRIMARY KEY): Auto-increment ID
- `user_email` (FOREIGN KEY): References users.email
- `recipe_id`: Recipe identifier
- `status`: Progress status (viewed, in_progress, completed)
- `position`: Position in recipe (optional)
- `timestamp`: Last update timestamp

### Activities Table (PERSISTENT - NEVER DELETED)
- `id` (PRIMARY KEY): Auto-increment ID
- `user_email` (FOREIGN KEY, INDEXED): References users.email
- `activity`: Activity description (e.g., "search:chicken", "added_favorite:123")
- `timestamp` (INDEXED): Activity timestamp in milliseconds

**Important**: Activities are designed to persist forever. They are never deleted, ensuring complete activity history per user.

## API Endpoints

### Authentication
- `POST /signup` - Register new user
- `POST /login` - Login and get JWT token
- `GET /me` - Get current user info (JWT required)

### Favorites
- `GET /favorites` - Get user favorites (JWT required)
- `POST /favorites` - Add favorite (JWT required)
- `DELETE /favorites/<id>` - Remove favorite (JWT required)

### Progress
- `GET /progress` - Get user progress (JWT required)
- `POST /progress` - Set progress (JWT required)
- `DELETE /progress/<id>` - Delete progress (JWT required)

### Activities
- `GET /activities?limit=N` - Get user activities (JWT required)
  - Returns all activities, ordered by timestamp (newest first)
  - Optional `limit` parameter (max 1000)
- `POST /activities` - Add activity (JWT required)
  - Body: `{"activity": "search:chicken", "timestamp": 1234567890}`
  - `timestamp` is optional (uses current time if not provided)

## Activity Persistence

Activities are automatically saved when:
- User signs up (`signup`)
- User logs in (`login`)
- User adds/removes favorites (`added_favorite:<id>`, `removed_favorite:<id>`)
- User updates progress (`progress:<id>:<status>`)
- User searches (`search:<query>`) - via POST /activities

All activities are:
- **Permanently stored** in the database
- **Never deleted** (even on user logout)
- **Tied to user account** via user_email
- **Indexed** for fast queries
- **Deduplicated** (same activity within 1 second is considered duplicate)

## Testing

Test the backend with curl:

```bash
# Signup
curl -X POST http://localhost:5000/signup \
  -H "Content-Type: application/json" \
  -d '{"name":"Test User","email":"test@example.com","password":"test123"}'

# Login
curl -X POST http://localhost:5000/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"test123"}'

# Get activities (replace TOKEN with JWT from login)
curl -X GET http://localhost:5000/activities \
  -H "Authorization: Bearer TOKEN"
```

## Environment Variables

Create a `.env` file (optional):
```
DATABASE_URL=sqlite:///./app.db
SECRET_KEY=your-secret-key-here
JWT_SECRET_KEY=your-jwt-secret-key-here
```

## Production Notes

- For production, use PostgreSQL or MySQL instead of SQLite
- Set strong SECRET_KEY and JWT_SECRET_KEY
- Enable HTTPS
- Configure proper CORS origins (currently allows all)
- Set up database backups (activities are permanent!)

