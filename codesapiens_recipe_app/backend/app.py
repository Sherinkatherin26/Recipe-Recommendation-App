import os
from flask import Flask, request, jsonify
from flask_jwt_extended import JWTManager, create_access_token, jwt_required, get_jwt_identity
from flask_cors import CORS
from dotenv import load_dotenv
from db import init_db, db
from models import User, Favorite, Progress, Activity

load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), '.env'))

def create_app():
    app = Flask(__name__)
    app.config['SQLALCHEMY_DATABASE_URI'] = os.environ.get('DATABASE_URL', 'sqlite:///./app.db')
    app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
    app.config['SECRET_KEY'] = os.environ.get('SECRET_KEY', 'dev')
    app.config['JWT_SECRET_KEY'] = os.environ.get('JWT_SECRET_KEY', 'jwt-secret')

    # Enable CORS for all routes
    CORS(app, resources={r"/*": {"origins": "*"}})

    init_db(app)

    jwt = JWTManager(app)

    @app.route('/signup', methods=['POST'])
    def signup():
        data = request.get_json() or {}
        name = data.get('name', '')
        email = data.get('email', '').strip()
        password = data.get('password', '')
        if not email or not password:
            return jsonify({'error': 'Missing email or password'}), 400
        if User.query.filter_by(email=email).first():
            return jsonify({'error': 'Account exists'}), 400
        user = User(email=email, name=name)
        user.set_password(password)
        db.session.add(user)
        db.session.commit()
        # record activity
        act = Activity(user_email=email, activity='signup')
        db.session.add(act)
        db.session.commit()
        access = create_access_token(identity=email)
        return jsonify({'access_token': access, 'email': email, 'name': name})

    @app.route('/login', methods=['POST'])
    def login():
        data = request.get_json() or {}
        email = data.get('email', '').strip()
        password = data.get('password', '')
        if not email or not password:
            return jsonify({'error': 'Missing email/password'}), 400
        user = User.query.filter_by(email=email).first()
        if not user or not user.check_password(password):
            return jsonify({'error': 'Invalid credentials'}), 401
        access = create_access_token(identity=email)
        # record login
        act = Activity(user_email=email, activity='login')
        db.session.add(act)
        db.session.commit()
        return jsonify({'access_token': access, 'email': email, 'name': user.name})

    @app.route('/me', methods=['GET'])
    @jwt_required()
    def me():
        email = get_jwt_identity()
        user = User.query.filter_by(email=email).first()
        if not user:
            return jsonify({'error': 'Not found'}), 404
        return jsonify({'email': user.email, 'name': user.name})

    # Favorites
    @app.route('/favorites', methods=['GET'])
    @jwt_required()
    def get_favorites():
        email = get_jwt_identity()
        rows = Favorite.query.filter_by(user_email=email).all()
        return jsonify([r.recipe_id for r in rows])

    @app.route('/favorites', methods=['POST'])
    @jwt_required()
    def add_favorite():
        email = get_jwt_identity()
        data = request.get_json() or {}
        rid = data.get('id')
        if not rid:
            return jsonify({'error': 'Missing id'}), 400
        if not Favorite.query.filter_by(user_email=email, recipe_id=rid).first():
            fav = Favorite(user_email=email, recipe_id=rid)
            db.session.add(fav)
            db.session.commit()
        # record activity
        db.session.add(Activity(user_email=email, activity=f'added_favorite:{rid}'))
        db.session.commit()
        return jsonify({'ok': True})

    @app.route('/favorites/<rid>', methods=['DELETE'])
    @jwt_required()
    def remove_favorite(rid):
        email = get_jwt_identity()
        Favorite.query.filter_by(user_email=email, recipe_id=rid).delete()
        # Record activity - activities are NEVER deleted, they persist forever
        db.session.add(Activity(user_email=email, activity=f'removed_favorite:{rid}'))
        db.session.commit()
        return jsonify({'ok': True})

    # Progress
    @app.route('/progress', methods=['GET'])
    @jwt_required()
    def get_progress():
        email = get_jwt_identity()
        rows = Progress.query.filter_by(user_email=email).all()
        out = []
        for r in rows:
            out.append({'id': r.recipe_id, 'status': r.status, 'position': r.position, 'timestamp': r.timestamp})
        return jsonify(out)

    @app.route('/progress', methods=['POST'])
    @jwt_required()
    def set_progress():
        email = get_jwt_identity()
        data = request.get_json() or {}
        rid = data.get('id')
        status = data.get('status')
        position = data.get('position', 0)
        if not rid or not status:
            return jsonify({'error': 'Missing id or status'}), 400
        existing = Progress.query.filter_by(user_email=email, recipe_id=rid).first()
        if existing:
            existing.status = status
            existing.position = position
            existing.timestamp = int(__import__('time').time() * 1000)
        else:
            existing = Progress(user_email=email, recipe_id=rid, status=status, position=position)
            db.session.add(existing)
        db.session.add(Activity(user_email=email, activity=f'progress:{rid}:{status}'))
        db.session.commit()
        return jsonify({'ok': True})

    @app.route('/progress/<rid>', methods=['DELETE'])
    @jwt_required()
    def delete_progress(rid):
        email = get_jwt_identity()
        Progress.query.filter_by(user_email=email, recipe_id=rid).delete()
        db.session.commit()
        return jsonify({'ok': True})

    # Activities
    @app.route('/activities', methods=['GET'])
    @jwt_required()
    def get_activities():
        try:
            email = get_jwt_identity()
            # Get optional limit parameter (default: return all, max: 1000)
            limit = request.args.get('limit', type=int)
            if limit and limit > 1000:
                limit = 1000
            if limit and limit < 1:
                limit = None
            
            query = Activity.query.filter_by(user_email=email).order_by(Activity.timestamp.desc())
            if limit:
                rows = query.limit(limit).all()
            else:
                rows = query.all()
            
            out = []
            for r in rows:
                out.append({
                    'email': r.user_email,
                    'activity': r.activity,
                    'timestamp': r.timestamp
                })
            return jsonify(out)
        except Exception as e:
            return jsonify({'error': str(e)}), 500

    @app.route('/activities', methods=['POST'])
    @jwt_required()
    def add_activity():
        try:
            email = get_jwt_identity()
            data = request.get_json() or {}
            activity = data.get('activity')
            timestamp = data.get('timestamp')
            if not activity:
                return jsonify({'error': 'Missing activity'}), 400
            
            # Use provided timestamp or current time
            if not timestamp:
                timestamp = int(__import__('time').time() * 1000)
            
            # Check for duplicate (same user, activity, and timestamp within 1 second)
            # This prevents exact duplicates while allowing similar activities
            from sqlalchemy import func
            existing = Activity.query.filter_by(
                user_email=email,
                activity=activity
            ).filter(
                func.abs(Activity.timestamp - timestamp) < 1000
            ).first()
            
            if existing:
                # Duplicate activity, return success without creating new record
                return jsonify({'ok': True, 'duplicate': True})
            
            # Create new activity - these are NEVER deleted, they persist forever
            act = Activity(user_email=email, activity=activity, timestamp=timestamp)
            db.session.add(act)
            db.session.commit()
            return jsonify({'ok': True})
        except Exception as e:
            db.session.rollback()
            return jsonify({'error': str(e)}), 500

    return app


if __name__ == '__main__':
    app = create_app()
    app.run(host='0.0.0.0', port=5000)
