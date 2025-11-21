# Recipe Recommendation App Backend

Flask-based REST API backend for the Recipe Recommendation App.

## Setup

1. Install dependencies:
```bash
pip install -r requirements.txt
```

2. Create a `.env` file (optional):
```
DATABASE_URL=sqlite:///./app.db
SECRET_KEY=your-secret-key-here
JWT_SECRET_KEY=your-jwt-secret-key-here
```

3. Run the server:
```bash
python app.py
```

The server will run on `http://0.0.0.0:5000`

## Database

The database is automatically created on first run. It uses SQLite by default.

### Tables

- **users**: User accounts (email, name, password_hash)
- **favorites**: User favorite recipes (user_email, recipe_id)
- **progress**: Recipe progress tracking (user_email, recipe_id, status, position, timestamp)
- **activities**: User activity log (user_email, activity, timestamp) - **NEVER DELETED, PERSISTS FOREVER**

### Activities Persistence

Activities are designed to persist permanently:
- Activities are **never deleted** from the database
- Each activity is tied to a user account
- Activities are indexed for fast queries by user and timestamp
- Duplicate prevention ensures data integrity

## API Endpoints

### Authentication
- `POST /signup` - Create new user account
- `POST /login` - Login and get JWT token
- `GET /me` - Get current user info (requires JWT)

### Favorites
- `GET /favorites` - Get user's favorite recipes (requires JWT)
- `POST /favorites` - Add favorite recipe (requires JWT)
- `DELETE /favorites/<recipe_id>` - Remove favorite recipe (requires JWT)

### Progress
- `GET /progress` - Get user's recipe progress (requires JWT)
- `POST /progress` - Set recipe progress (requires JWT)
- `DELETE /progress/<recipe_id>` - Delete recipe progress (requires JWT)

### Activities
- `GET /activities` - Get user's activities (requires JWT)
  - Optional query param: `?limit=N` (max 1000)
- `POST /activities` - Add activity (requires JWT)
  - Body: `{"activity": "search:chicken", "timestamp": 1234567890}` (timestamp optional)

## CORS

CORS is enabled for all origins to allow frontend connections.

## Security Notes

- Passwords are hashed using Werkzeug's password hashing
- JWT tokens are required for protected endpoints
- User activities are permanently stored and tied to user accounts

