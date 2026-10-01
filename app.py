import os
import time
import sqlite3
import random
from datetime import datetime, timedelta
from flask import Flask, request, jsonify
from flask_cors import CORS
from werkzeug.security import generate_password_hash, check_password_hash
from werkzeug.utils import secure_filename
from google import genai
from google.genai import types

app = Flask(__name__)
CORS(app)

# CONFIGURATION
UPLOAD_FOLDER = 'static/uploads'
os.makedirs(UPLOAD_FOLDER, exist_ok=True)
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

# INITIALIZE GOOGLE AI CLIENT
GEMINI_API_KEY = "AQ.Ab8RN6L38tUETkvV4SAi0rlRfhjOSsCvSlmuBI8BhNbiU_pqiQ"
client = genai.Client(api_key=GEMINI_API_KEY, http_options={'api_version': 'v1alpha'})

# DATABASE SETUP
def init_db():
    conn = sqlite3.connect('users.db')
    c = conn.cursor()
    
    # Users table
    c.execute('''CREATE TABLE IF NOT EXISTS users 
                 (id INTEGER PRIMARY KEY AUTOINCREMENT, 
                  email TEXT UNIQUE, 
                  password TEXT, 
                  trials INTEGER DEFAULT 5, 
                  ai_coaching INTEGER DEFAULT 0,
                  dream_analysis INTEGER DEFAULT 0,
                  tier TEXT DEFAULT 'free',
                  current_streak INTEGER DEFAULT 0,
                  total_wins INTEGER DEFAULT 0,
                  last_check_in TEXT,
                  daily_reminders INTEGER DEFAULT 1)''')
    
    # Dreams table
    c.execute('''CREATE TABLE IF NOT EXISTS dreams
                 (id INTEGER PRIMARY KEY AUTOINCREMENT,
                  user_id INTEGER,
                  title TEXT,
                  category TEXT,
                  description TEXT,
                  target_date TEXT,
                  image_url TEXT,
                  is_completed INTEGER DEFAULT 0,
                  progress_percent INTEGER DEFAULT 0,
                  created_at TEXT,
                  FOREIGN KEY (user_id) REFERENCES users(id))''')
    
    # Micro Actions table
    c.execute('''CREATE TABLE IF NOT EXISTS micro_actions
                 (id INTEGER PRIMARY KEY AUTOINCREMENT,
                  dream_id INTEGER,
                  title TEXT,
                  description TEXT,
                  is_completed INTEGER DEFAULT 0,
                  completed_at TEXT,
                  FOREIGN KEY (dream_id) REFERENCES dreams(id))''')
    
    # Challenges table
    c.execute('''CREATE TABLE IF NOT EXISTS challenges
                 (id INTEGER PRIMARY KEY AUTOINCREMENT,
                  title TEXT,
                  description TEXT,
                  category TEXT,
                  duration_days INTEGER,
                  participant_count INTEGER DEFAULT 0)''')
    
    # User Challenges table
    c.execute('''CREATE TABLE IF NOT EXISTS user_challenges
                 (id INTEGER PRIMARY KEY AUTOINCREMENT,
                  user_id INTEGER,
                  challenge_id INTEGER,
                  start_date TEXT,
                  is_active INTEGER DEFAULT 1,
                  FOREIGN KEY (user_id) REFERENCES users(id),
                  FOREIGN KEY (challenge_id) REFERENCES challenges(id))''')
    
    # Wins table
    c.execute('''CREATE TABLE IF NOT EXISTS wins
                 (id INTEGER PRIMARY KEY AUTOINCREMENT,
                  user_id INTEGER,
                  title TEXT,
                  description TEXT,
                  category TEXT,
                  achieved_at TEXT,
                  image_url TEXT,
                  FOREIGN KEY (user_id) REFERENCES users(id))''')
    
    conn.commit()
    
    # Seed some default challenges
    _seed_challenges(c, conn)
    
    conn.close()

def _seed_challenges(cursor, conn):
    # Check if challenges already exist
    cursor.execute("SELECT COUNT(*) FROM challenges")
    if cursor.fetchone()[0] > 0:
        return
    
    challenges = [
        ("30-Day Solo Adventure Prep", "Prepare for your first solo trip with daily micro-actions", "Travel", 30, 245),
        ("Salary Negotiation Mastery", "Build confidence to negotiate your dream salary in 14 days", "Career", 14, 189),
        ("Financial Freedom Sprint", "Start your journey to financial independence", "Financial", 21, 312),
        ("Morning Ritual Challenge", "Build a powerful morning routine that sets you up for success", "Health", 30, 567),
        ("Dream Vision Board", "Clarify and visualize your biggest dreams in 7 days", "Personal", 7, 423),
        ("Networking Power Week", "Expand your professional network with daily outreach", "Career", 7, 156),
        ("Bucket List Kickstart", "Turn one bucket list item into a concrete plan", "Adventure", 14, 289),
    ]
    
    for title, desc, category, duration, participants in challenges:
        cursor.execute(
            "INSERT INTO challenges (title, description, category, duration_days, participant_count) VALUES (?, ?, ?, ?, ?)",
            (title, desc, category, duration, participants)
        )
    
    conn.commit()

init_db()

# === AUTH ROUTES ===

@app.route('/auth/register', methods=['POST'])
def register():
    data = request.json
    email = data.get('email')
    password = generate_password_hash(data.get('password'))
    
    try:
        conn = sqlite3.connect('users.db')
        c = conn.cursor()
        c.execute("INSERT INTO users (email, password) VALUES (?, ?)", (email, password))
        conn.commit()
        
        # Fetch the newly created user
        user_id = c.lastrowid
        c.execute("SELECT * FROM users WHERE id = ?", (user_id,))
        user = c.fetchone()
        conn.close()
        
        return jsonify({
            'success': True,
            'message': 'User registered',
            'user': {
                'user_id': str(user[0]),
                'email': user[1],
                'trials_remaining': user[3],
                'ai_coaching_remaining': user[4],
                'dream_analysis_remaining': user[5],
                'tier': user[6],
                'current_streak': user[7],
                'total_wins': user[8],
                'last_check_in': user[9],
                'daily_reminders': bool(user[10])
            }
        })
    except:
        return jsonify({'success': False, 'message': 'User already exists'}), 400

@app.route('/auth/login', methods=['POST'])
def login():
    data = request.json
    conn = sqlite3.connect('users.db')
    c = conn.cursor()
    c.execute("SELECT * FROM users WHERE email = ?", (data.get('email'),))
    user = c.fetchone()
    conn.close()
    
    if user and check_password_hash(user[2], data.get('password')):
        return jsonify({
            'success': True,
            'user': {
                'user_id': str(user[0]),
                'email': user[1],
                'trials_remaining': user[3],
                'ai_coaching_remaining': user[4],
                'dream_analysis_remaining': user[5],
                'tier': user[6],
                'current_streak': user[7],
                'total_wins': user[8],
                'last_check_in': user[9],
                'daily_reminders': bool(user[10])
            }
        })
    return jsonify({'success': False, 'message': 'Invalid credentials'}), 401

@app.route('/auth/google', methods=['POST'])
def google_login():
    # Simplified - in production, verify the Google ID token
    data = request.json
    email = "google_user@example.com"  # Extract from verified token
    
    conn = sqlite3.connect('users.db')
    c = conn.cursor()
    c.execute("SELECT * FROM users WHERE email = ?", (email,))
    user = c.fetchone()
    
    if not user:
        # Create new user
        c.execute("INSERT INTO users (email, password) VALUES (?, ?)", 
                  (email, generate_password_hash('google_oauth')))
        conn.commit()
        user_id = c.lastrowid
        c.execute("SELECT * FROM users WHERE id = ?", (user_id,))
        user = c.fetchone()
    
    conn.close()
    
    return jsonify({
        'success': True,
        'user': {
            'user_id': str(user[0]),
            'email': user[1],
            'trials_remaining': user[3],
            'ai_coaching_remaining': user[4],
            'dream_analysis_remaining': user[5],
            'tier': user[6],
            'current_streak': user[7],
            'total_wins': user[8],
            'last_check_in': user[9],
            'daily_reminders': bool(user[10])
        }
    })

# === USER ROUTES ===

@app.route('/user/<user_id>/profile', methods=['GET'])
def get_user_profile(user_id):
    conn = sqlite3.connect('users.db')
    c = conn.cursor()
    c.execute("SELECT * FROM users WHERE id = ?", (user_id,))
    user = c.fetchone()
    conn.close()
    
    if user:
        return jsonify({
            'success': True,
            'user': {
                'user_id': str(user[0]),
                'email': user[1],
                'trials_remaining': user[3],
                'ai_coaching_remaining': user[4],
                'dream_analysis_remaining': user[5],
                'tier': user[6],
                'current_streak': user[7],
                'total_wins': user[8],
                'last_check_in': user[9],
                'daily_reminders': bool(user[10])
            }
        })
    return jsonify({'success': False, 'message': 'User not found'}), 404

@app.route('/user/<user_id>/checkin', methods=['POST'])
def check_in(user_id):
    conn = sqlite3.connect('users.db')
    c = conn.cursor()
    c.execute("SELECT current_streak, last_check_in FROM users WHERE id = ?", (user_id,))
    result = c.fetchone()
    
    if not result:
        conn.close()
        return jsonify({'success': False, 'message': 'User not found'}), 404
    
    current_streak, last_check_in = result
    today = datetime.now().date()
    
    if last_check_in:
        last_date = datetime.fromisoformat(last_check_in).date()
        diff = (today - last_date).days
        
        if diff == 0:
            # Already checked in today
            new_streak = current_streak
        elif diff == 1:
            # Consecutive day
            new_streak = current_streak + 1
        else:
            # Streak broken
            new_streak = 1
    else:
        new_streak = 1
    
    c.execute("UPDATE users SET current_streak = ?, last_check_in = ? WHERE id = ?",
              (new_streak, today.isoformat(), user_id))
    conn.commit()
    conn.close()
    
    return jsonify({
        'success': True,
        'new_streak': new_streak,
        'message': f'Checked in! {new_streak} day streak!'
    })

# === DREAMS ROUTES ===

@app.route('/user/<user_id>/dreams', methods=['GET'])
def get_dreams(user_id):
    conn = sqlite3.connect('users.db')
    c = conn.cursor()
    c.execute("""
        SELECT id, title, category, description, target_date, image_url, 
               is_completed, progress_percent, created_at 
        FROM dreams WHERE user_id = ? ORDER BY created_at DESC
    """, (user_id,))
    
    dreams = []
    for row in c.fetchall():
        dream_id = row[0]
        
        # Get micro actions for this dream
        c.execute("""
            SELECT id, title, description, is_completed, completed_at 
            FROM micro_actions WHERE dream_id = ?
        """, (dream_id,))
        
        micro_actions = []
        for action in c.fetchall():
            micro_actions.append({
                'id': str(action[0]),
                'dream_id': str(dream_id),
                'title': action[1],
                'description': action[2],
                'is_completed': bool(action[3]),
                'completed_at': action[4]
            })
        
        dreams.append({
            'id': str(row[0]),
            'title': row[1],
            'category': row[2],
            'description': row[3],
            'target_date': row[4],
            'image_url': row[5] or '',
            'is_completed': bool(row[6]),
            'progress_percent': row[7],
            'micro_actions': micro_actions
        })
    
    conn.close()
    return jsonify({'success': True, 'dreams': dreams})

@app.route('/user/<user_id>/dreams', methods=['POST'])
def create_dream(user_id):
    data = request.json
    
    conn = sqlite3.connect('users.db')
    c = conn.cursor()
    c.execute("""
        INSERT INTO dreams (user_id, title, category, description, target_date, created_at)
        VALUES (?, ?, ?, ?, ?, ?)
    """, (
        user_id,
        data.get('title'),
        data.get('category'),
        data.get('description'),
        data.get('target_date'),
        datetime.now().isoformat()
    ))
    conn.commit()
    dream_id = c.lastrowid
    conn.close()
    
    return jsonify({
        'success': True,
        'dream_id': str(dream_id),
        'message': 'Dream created successfully'
    })

# === AI DREAM PLANNING ===

@app.route('/ai/dream-plan', methods=['POST'])
def generate_dream_plan():
    data = request.json
    user_id = data.get('user_id')
    dream_description = data.get('dream_description')
    
    # Check user credits
    conn = sqlite3.connect('users.db')
    c = conn.cursor()
    c.execute("SELECT trials, dream_analysis, tier FROM users WHERE id = ?", (user_id,))
    user = c.fetchone()
    
    if not user:
        conn.close()
        return jsonify({'success': False, 'message': 'User not found'}), 404
    
    trials, dream_analysis, tier = user
    
    if dream_analysis > 0:
        # Use dream analysis credit
        c.execute("UPDATE users SET dream_analysis = dream_analysis - 1 WHERE id = ?", (user_id,))
    elif trials > 0:
        # Use trial credit
        c.execute("UPDATE users SET trials = trials - 1 WHERE id = ?", (user_id,))
    else:
        conn.close()
        return jsonify({'success': False, 'message': 'No credits remaining'}), 403
    
    conn.commit()
    conn.close()
    
    # Generate AI plan using Gemini 3 Flash
    prompt = f"""You are an expert life coach helping ambitious women achieve their dreams.

Dream: {dream_description}

Create a detailed, actionable plan with:
1. 3-5 major milestones to achieve this dream
2. 5-10 specific micro-actions they can start TODAY
3. Timeline breakdown (what to do in the next week, month, 3 months)
4. Potential obstacles and how to overcome them
5. Motivational message

Make it practical, empowering, and action-oriented. Focus on removing barriers and building confidence."""

    try:
        response = client.models.generate_content(
            model="gemini-3-flash-preview",
            contents=prompt,
            config=types.GenerateContentConfig(
                thinking_config=types.ThinkingConfig(thinking_level="medium")
            )
        )
        
        return jsonify({
            'success': True,
            'plan': response.text
        })
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

# === DAILY CHALLENGE ===

@app.route('/user/<user_id>/daily-challenge', methods=['GET'])
def get_daily_challenge(user_id):
    # Generate a daily micro-action using AI
    challenges = [
        {
            'title': 'Research One Destination',
            'description': 'Pick a place you\'ve always wanted to visit and spend 15 minutes researching flights, accommodations, or must-see spots. Make it real by looking at dates.'
        },
        {
            'title': 'Practice Your Power Pose',
            'description': 'Spend 2 minutes in a power pose before your next meeting or important task. Stand tall, shoulders back, and visualize success.'
        },
        {
            'title': 'Update Your Resume',
            'description': 'Add one recent accomplishment to your resume. Quantify your impact with numbers if possible.'
        },
        {
            'title': 'Set a Micro-Savings Goal',
            'description': 'Transfer $5, $10, or whatever you can to a separate savings account labeled with your dream (e.g., "Japan Fund").'
        },
        {
            'title': 'Send One Networking Message',
            'description': 'Reach out to someone in your dream industry or location. Ask for a 15-minute coffee chat (virtual or in-person).'
        },
        {
            'title': 'Learn 5 Key Phrases',
            'description': 'If you have a destination in mind, learn 5 useful phrases in the local language. Practice saying them out loud.'
        },
        {
            'title': 'Write Your Future Self a Letter',
            'description': 'Describe your life one year from now as if you\'ve already achieved your biggest goal. Be specific and emotional.'
        },
        {
            'title': 'Create a Vision Board Item',
            'description': 'Find or create one image that represents your dream. Save it to a folder or add it to a physical vision board.'
        }
    ]
    
    # Use day of year to ensure consistency within a day
    day_of_year = datetime.now().timetuple().tm_yday
    challenge = challenges[day_of_year % len(challenges)]
    
    return jsonify({
        'success': True,
        'challenge': challenge
    })

# === CHALLENGES ===

@app.route('/challenges', methods=['GET'])
def get_challenges():
    conn = sqlite3.connect('users.db')
    c = conn.cursor()
    c.execute("SELECT id, title, description, category, duration_days, participant_count FROM challenges")
    
    challenges = []
    for row in c.fetchall():
        challenges.append({
            'id': str(row[0]),
            'title': row[1],
            'description': row[2],
            'category': row[3],
            'duration_days': row[4],
            'participant_count': row[5],
            'daily_tasks': [],  # Could be expanded
            'is_active': False,
            'start_date': None
        })
    
    conn.close()
    return jsonify({'success': True, 'challenges': challenges})

@app.route('/user/<user_id>/challenges/<challenge_id>/join', methods=['POST'])
def join_challenge(user_id, challenge_id):
    conn = sqlite3.connect('users.db')
    c = conn.cursor()
    
    # Check if already joined
    c.execute("""
        SELECT id FROM user_challenges 
        WHERE user_id = ? AND challenge_id = ? AND is_active = 1
    """, (user_id, challenge_id))
    
    if c.fetchone():
        conn.close()
        return jsonify({'success': False, 'message': 'Already joined this challenge'})
    
    # Join challenge
    c.execute("""
        INSERT INTO user_challenges (user_id, challenge_id, start_date, is_active)
        VALUES (?, ?, ?, 1)
    """, (user_id, challenge_id, datetime.now().isoformat()))
    
    # Increment participant count
    c.execute("""
        UPDATE challenges SET participant_count = participant_count + 1
        WHERE id = ?
    """, (challenge_id,))
    
    conn.commit()
    conn.close()
    
    return jsonify({'success': True, 'message': 'Challenge joined!'})

# === WINS ===

@app.route('/user/<user_id>/wins', methods=['GET'])
def get_wins(user_id):
    conn = sqlite3.connect('users.db')
    c = conn.cursor()
    c.execute("""
        SELECT id, title, description, category, achieved_at, image_url
        FROM wins WHERE user_id = ? ORDER BY achieved_at DESC
    """, (user_id,))
    
    wins = []
    for row in c.fetchall():
        wins.append({
            'id': str(row[0]),
            'title': row[1],
            'description': row[2],
            'category': row[3],
            'achieved_at': row[4],
            'image_url': row[5] or ''
        })
    
    conn.close()
    return jsonify({'success': True, 'wins': wins})

@app.route('/user/<user_id>/wins', methods=['POST'])
def log_win(user_id):
    data = request.json
    
    conn = sqlite3.connect('users.db')
    c = conn.cursor()
    
    c.execute("""
        INSERT INTO wins (user_id, title, description, category, achieved_at)
        VALUES (?, ?, ?, ?, ?)
    """, (
        user_id,
        data.get('title'),
        data.get('description', ''),
        data.get('category'),
        data.get('achieved_at', datetime.now().isoformat())
    ))
    
    # Increment total wins
    c.execute("UPDATE users SET total_wins = total_wins + 1 WHERE id = ?", (user_id,))
    
    conn.commit()
    conn.close()
    
    return jsonify({'success': True, 'message': 'Win logged!'})

# === AI COACHING ===

@app.route('/ai/coaching', methods=['POST'])
def ai_coaching():
    data = request.json
    user_id = data.get('user_id')
    question = data.get('question')
    
    # Check user credits
    conn = sqlite3.connect('users.db')
    c = conn.cursor()
    c.execute("SELECT trials, ai_coaching, tier FROM users WHERE id = ?", (user_id,))
    user = c.fetchone()
    
    if not user:
        conn.close()
        return jsonify({'success': False, 'message': 'User not found'}), 404
    
    trials, ai_coaching, tier = user
    
    if ai_coaching > 0:
        c.execute("UPDATE users SET ai_coaching = ai_coaching - 1 WHERE id = ?", (user_id,))
    elif trials > 0:
        c.execute("UPDATE users SET trials = trials - 1 WHERE id = ?", (user_id,))
    else:
        conn.close()
        return jsonify({'success': False, 'message': 'No credits remaining'}), 403
    
    conn.commit()
    conn.close()
    
    # Get AI coaching response
    prompt = f"""You are Gabby Beckford's AI coach, helping ambitious women aged 25-45 achieve their dreams.

Your personality: Warm, encouraging, direct, action-oriented. You push people gently but firmly toward their goals. You believe in them completely.

User's question: {question}

Provide:
1. Empathetic acknowledgment of their concern
2. Specific, actionable advice
3. One micro-action they can take TODAY
4. Motivational closing

Keep it conversational, empowering, and under 200 words."""

    try:
        response = client.models.generate_content(
            model="gemini-3-flash-preview",
            contents=prompt,
            config=types.GenerateContentConfig(
                thinking_config=types.ThinkingConfig(thinking_level="medium")
            )
        )
        
        return jsonify({
            'success': True,
            'response': response.text
        })
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

# === AI RESEARCH (with Google Search) ===

@app.route('/ai/research', methods=['POST'])
def ai_research():
    data = request.json
    user_id = data.get('user_id')
    query = data.get('query')
    
    # Check user credits
    conn = sqlite3.connect('users.db')
    c = conn.cursor()
    c.execute("SELECT trials, tier FROM users WHERE id = ?", (user_id,))
    user = c.fetchone()
    
    if not user:
        conn.close()
        return jsonify({'success': False, 'message': 'User not found'}), 404
    
    trials, tier = user
    
    if trials > 0:
        c.execute("UPDATE users SET trials = trials - 1 WHERE id = ?", (user_id,))
    else:
        conn.close()
        return jsonify({'success': False, 'message': 'No credits remaining'}), 403
    
    conn.commit()
    conn.close()
    
    # Use Gemini with Google Search grounding
    try:
        response = client.models.generate_content(
            model="gemini-3-flash-preview",
            contents=f"""Research this for an ambitious woman planning her dream life:

{query}

Provide:
- Key facts and current information
- Practical tips and insider advice
- Budget considerations
- Timeline recommendations
- Next steps to take

Make it actionable and inspiring!""",
            config=types.GenerateContentConfig(
                tools=[{"google_search": {}}],
                thinking_config=types.ThinkingConfig(thinking_level="high")
            )
        )
        
        return jsonify({
            'success': True,
            'research': response.text
        })
    except Exception as e:
        return jsonify({'success': False, 'message': str(e)}), 500

# === MICRO ACTIONS ===

@app.route('/user/<user_id>/micro-actions/<action_id>/complete', methods=['POST'])
def complete_micro_action(user_id, action_id):
    conn = sqlite3.connect('users.db')
    c = conn.cursor()
    
    c.execute("""
        UPDATE micro_actions 
        SET is_completed = 1, completed_at = ?
        WHERE id = ?
    """, (datetime.now().isoformat(), action_id))
    
    # Update dream progress
    c.execute("""
        SELECT dream_id FROM micro_actions WHERE id = ?
    """, (action_id,))
    dream_id = c.fetchone()
    
    if dream_id:
        dream_id = dream_id[0]
        
        # Calculate progress
        c.execute("""
            SELECT COUNT(*) as total,
                   SUM(CASE WHEN is_completed = 1 THEN 1 ELSE 0 END) as completed
            FROM micro_actions WHERE dream_id = ?
        """, (dream_id,))
        
        result = c.fetchone()
        total, completed = result
        progress = int((completed / total * 100)) if total > 0 else 0
        
        c.execute("""
            UPDATE dreams SET progress_percent = ? WHERE id = ?
        """, (progress, dream_id))
    
    conn.commit()
    conn.close()
    
    return jsonify({
        'success': True,
        'message': 'Micro-action completed! 🎉'
    })

if __name__ == '__main__':
    app.run(debug=True, port=5000)