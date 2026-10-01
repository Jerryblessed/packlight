import os
import time
import sqlite3
import random
import requests
from datetime import datetime, timedelta
from flask import Flask, request, jsonify
from flask_cors import CORS
from werkzeug.security import generate_password_hash, check_password_hash

app = Flask(__name__)
CORS(app)

# ==========================================
# CONFIGURATION & ENVIRONMENT
# ==========================================
DB_PATH = 'users.db'
ADMIN_KEY = os.environ.get("ADMIN_KEY", "MyFallbackKey2026!")

# Microsoft Foundry Configuration (gpt-5.4-nano)
AI_ENDPOINT = os.environ.get(
    "AI_ENDPOINT",
    "https://opejeremiah-2939-resource.services.ai.azure.com/openai/v1/chat/completions"
)
AI_KEY = os.environ.get(
    "AI_KEY",
    "5rU3LmcHk8WjNdiyJ30vbmsTNGuHhFfe9Ln5hXz6DtkrqOYWSB7IJQQJ99CEAC1i4TkXJ3w3AAAAACOG5h7l"
)
AI_MODEL = "gpt-5.4-nano"

# ==========================================
# BULLETPROOF DATABASE CONNECTION
# ==========================================
def get_db():
    conn = sqlite3.connect(DB_PATH, timeout=30.0)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA journal_mode=WAL;")
    conn.execute("PRAGMA synchronous=NORMAL;")
    return conn

def init_db():
    conn = get_db()
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
                  daily_reminders INTEGER DEFAULT 1,
                  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)''')
    
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
                  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
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
    _seed_challenges(c, conn)
    conn.close()

def _seed_challenges(cursor, conn):
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

# ==========================================
# AI CALLER (Microsoft Foundry gpt-5.4-nano)
# ==========================================
def call_gpt_nano(prompt, system_instruction="You are Gabby Beckford's AI coach, helping ambitious women achieve their dreams."):
    headers = {
        "Content-Type": "application/json",
        "api-key": AI_KEY,
        "Authorization": f"Bearer {AI_KEY}"
    }

    target_url = AI_ENDPOINT
    if target_url.endswith("/responses"):
        target_url = target_url.replace("/responses", "/chat/completions")

    payload = {
        "model": AI_MODEL,
        "messages": [
            {"role": "system", "content": system_instruction},
            {"role": "user", "content": prompt}
        ],
        "temperature": 0.7
    }

    try:
        res = requests.post(target_url, headers=headers, json=payload, timeout=25)
        if res.status_code == 200:
            return res.json()['choices'][0]['message']['content'].strip()
        else:
            return "Take one small micro-action today to build momentum towards your dream!"
    except Exception as e:
        return f"Focus on what you can control today. (Service notice: {str(e)})"

# ==========================================
# AUTH ROUTES
# ==========================================
@app.route('/auth/register', methods=['POST'])
def register():
    data = request.json or {}
    email = data.get('email', '').strip().lower()
    password = data.get('password', '')
    
    if not email or not password:
        return jsonify({'success': False, 'message': 'Email and password required'}), 400

    hashed = generate_password_hash(password)
    
    try:
        conn = get_db()
        c = conn.cursor()
        c.execute("INSERT INTO users (email, password) VALUES (?, ?)", (email, hashed))
        user_id = c.lastrowid
        conn.commit()
        
        user = c.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
        conn.close()
        
        return jsonify({
            'success': True,
            'message': 'User registered',
            'user': {
                'user_id': str(user['id']),
                'email': user['email'],
                'trials_remaining': user['trials'],
                'ai_coaching_remaining': user['ai_coaching'],
                'dream_analysis_remaining': user['dream_analysis'],
                'tier': user['tier'],
                'current_streak': user['current_streak'],
                'total_wins': user['total_wins'],
                'last_check_in': user['last_check_in'],
                'daily_reminders': bool(user['daily_reminders'])
            }
        })
    except sqlite3.IntegrityError:
        return jsonify({'success': False, 'message': 'User already exists'}), 400
    except Exception as e:
        return jsonify({'success': False, 'message': f'Registration failed: {str(e)}'}), 500

@app.route('/auth/login', methods=['POST'])
def login():
    data = request.json or {}
    email = data.get('email', '').strip().lower()
    password = data.get('password', '')
    
    conn = get_db()
    c = conn.cursor()
    user = c.execute("SELECT * FROM users WHERE email = ?", (email,)).fetchone()
    conn.close()
    
    if user and check_password_hash(user['password'], password):
        return jsonify({
            'success': True,
            'user': {
                'user_id': str(user['id']),
                'email': user['email'],
                'trials_remaining': user['trials'],
                'ai_coaching_remaining': user['ai_coaching'],
                'dream_analysis_remaining': user['dream_analysis'],
                'tier': user['tier'],
                'current_streak': user['current_streak'],
                'total_wins': user['total_wins'],
                'last_check_in': user['last_check_in'],
                'daily_reminders': bool(user['daily_reminders'])
            }
        })
    return jsonify({'success': False, 'message': 'Invalid credentials'}), 401

@app.route('/auth/google', methods=['POST'])
def google_login():
    email = f"google_user_{int(time.time())}@gmail.com"
    try:
        conn = get_db()
        c = conn.cursor()
        c.execute("INSERT INTO users (email, password) VALUES (?, ?)", 
                  (email, generate_password_hash('google_oauth')))
        user_id = c.lastrowid
        conn.commit()
        user = c.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
        conn.close()
        
        return jsonify({
            'success': True,
            'user': {
                'user_id': str(user['id']),
                'email': user['email'],
                'trials_remaining': user['trials'],
                'ai_coaching_remaining': user['ai_coaching'],
                'dream_analysis_remaining': user['dream_analysis'],
                'tier': user['tier'],
                'current_streak': user['current_streak'],
                'total_wins': user['total_wins'],
                'last_check_in': user['last_check_in'],
                'daily_reminders': bool(user['daily_reminders'])
            }
        })
    except Exception as e:
        return jsonify({'success': False, 'message': f'Google auth failed: {str(e)}'}), 400

# ==========================================
# USER PROFILE & STREAK
# ==========================================
@app.route('/user/<user_id>/profile', methods=['GET'])
def get_user_profile(user_id):
    conn = get_db()
    c = conn.cursor()
    user = c.execute("SELECT * FROM users WHERE id = ?", (user_id,)).fetchone()
    conn.close()
    
    if user:
        return jsonify({
            'success': True,
            'user': {
                'user_id': str(user['id']),
                'email': user['email'],
                'trials_remaining': user['trials'],
                'ai_coaching_remaining': user['ai_coaching'],
                'dream_analysis_remaining': user['dream_analysis'],
                'tier': user['tier'],
                'current_streak': user['current_streak'],
                'total_wins': user['total_wins'],
                'last_check_in': user['last_check_in'],
                'daily_reminders': bool(user['daily_reminders'])
            }
        })
    return jsonify({'success': False, 'message': 'User not found'}), 404

@app.route('/user/<user_id>/checkin', methods=['POST'])
def check_in(user_id):
    conn = get_db()
    c = conn.cursor()
    user = c.execute("SELECT current_streak, last_check_in FROM users WHERE id = ?", (user_id,)).fetchone()
    
    if not user:
        conn.close()
        return jsonify({'success': False, 'message': 'User not found'}), 404
    
    current_streak = user['current_streak']
    last_check_in = user['last_check_in']
    today = datetime.utcnow().date()
    
    if last_check_in:
        last_date = datetime.fromisoformat(last_check_in).date()
        diff = (today - last_date).days
        if diff == 0:
            new_streak = current_streak
        elif diff == 1:
            new_streak = current_streak + 1
        else:
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

# ==========================================
# DREAMS & MICRO-ACTIONS
# ==========================================
@app.route('/user/<user_id>/dreams', methods=['GET'])
def get_dreams(user_id):
    conn = get_db()
    c = conn.cursor()
    dreams_data = c.execute(
        "SELECT * FROM dreams WHERE user_id = ? ORDER BY id DESC", (user_id,)
    ).fetchall()
    
    dreams = []
    for d in dreams_data:
        actions = c.execute(
            "SELECT * FROM micro_actions WHERE dream_id = ?", (d['id'],)
        ).fetchall()
        
        dreams.append({
            'id': str(d['id']),
            'title': d['title'],
            'category': d['category'],
            'description': d['description'],
            'target_date': d['target_date'],
            'image_url': d['image_url'] or '',
            'is_completed': bool(d['is_completed']),
            'progress_percent': d['progress_percent'],
            'micro_actions': [
                {
                    'id': str(a['id']),
                    'dream_id': str(d['id']),
                    'title': a['title'],
                    'description': a['description'],
                    'is_completed': bool(a['is_completed']),
                    'completed_at': a['completed_at']
                } for a in actions
            ]
        })
    conn.close()
    return jsonify({'success': True, 'dreams': dreams})

@app.route('/user/<user_id>/dreams', methods=['POST'])
def create_dream(user_id):
    data = request.json or {}
    conn = get_db()
    c = conn.cursor()
    c.execute("""
        INSERT INTO dreams (user_id, title, category, description, target_date, created_at)
        VALUES (?, ?, ?, ?, ?, ?)
    """, (
        user_id,
        data.get('title', 'My Dream'),
        data.get('category', 'Personal'),
        data.get('description', ''),
        data.get('target_date', datetime.utcnow().strftime('%Y-%m-%d')),
        datetime.utcnow().isoformat()
    ))
    conn.commit()
    dream_id = c.lastrowid
    conn.close()
    
    return jsonify({'success': True, 'dream_id': str(dream_id), 'message': 'Dream created successfully'})

@app.route('/user/<user_id>/micro-actions/<action_id>/complete', methods=['POST'])
def complete_micro_action(user_id, action_id):
    conn = get_db()
    c = conn.cursor()
    c.execute("UPDATE micro_actions SET is_completed = 1, completed_at = ? WHERE id = ?",
              (datetime.utcnow().isoformat(), action_id))
    
    item = c.execute("SELECT dream_id FROM micro_actions WHERE id = ?", (action_id,)).fetchone()
    if item:
        dream_id = item['dream_id']
        total = c.execute("SELECT COUNT(*) FROM micro_actions WHERE dream_id = ?", (dream_id,)).fetchone()[0]
        completed = c.execute("SELECT COUNT(*) FROM micro_actions WHERE dream_id = ? AND is_completed = 1", (dream_id,)).fetchone()[0]
        progress = int((completed / total * 100)) if total > 0 else 0
        c.execute("UPDATE dreams SET progress_percent = ? WHERE id = ?", (progress, dream_id))
    
    conn.commit()
    conn.close()
    return jsonify({'success': True, 'message': 'Micro-action completed! 🎉'})

# ==========================================
# AI ACTION PLANNING & COACHING
# ==========================================
@app.route('/ai/dream-plan', methods=['POST'])
def generate_dream_plan():
    data = request.json or {}
    user_id = data.get('user_id')
    dream_desc = data.get('dream_description', '')
    
    conn = get_db()
    c = conn.cursor()
    user = c.execute("SELECT trials, dream_analysis FROM users WHERE id = ?", (user_id,)).fetchone()
    if not user:
        conn.close()
        return jsonify({'success': False, 'message': 'User not found'}), 404
    
    if user['dream_analysis'] > 0:
        c.execute("UPDATE users SET dream_analysis = dream_analysis - 1 WHERE id = ?", (user_id,))
    elif user['trials'] > 0:
        c.execute("UPDATE users SET trials = trials - 1 WHERE id = ?", (user_id,))
    else:
        conn.close()
        return jsonify({'success': False, 'message': 'No credits remaining'}), 403
    
    conn.commit()
    conn.close()
    
    prompt = f"""
    Dream to Plan: "{dream_desc}"
    Create an empowering, action-oriented plan:
    1. 3 Major Milestones
    2. 5 Immediate daily micro-actions to begin TODAY
    3. Timeline breakdown (Week 1, Month 1, Month 3)
    4. Overcoming common fears & staying consistent
    """

    plan = call_gpt_nano(prompt)
    return jsonify({'success': True, 'plan': plan})

@app.route('/ai/coaching', methods=['POST'])
def ai_coaching():
    data = request.json or {}
    user_id = data.get('user_id')
    question = data.get('question', '')
    
    conn = get_db()
    c = conn.cursor()
    user = c.execute("SELECT trials, ai_coaching FROM users WHERE id = ?", (user_id,)).fetchone()
    if not user:
        conn.close()
        return jsonify({'success': False, 'message': 'User not found'}), 404
        
    if user['ai_coaching'] > 0:
        c.execute("UPDATE users SET ai_coaching = ai_coaching - 1 WHERE id = ?", (user_id,))
    elif user['trials'] > 0:
        c.execute("UPDATE users SET trials = trials - 1 WHERE id = ?", (user_id,))
    else:
        conn.close()
        return jsonify({'success': False, 'message': 'No credits remaining'}), 403
        
    conn.commit()
    conn.close()
    
    prompt = f"""
    User question: "{question}"
    Provide warm, empowering, direct guidance and 1 micro-action she can take right now. Under 200 words.
    """
    
    advice = call_gpt_nano(prompt)
    return jsonify({'success': True, 'response': advice})

@app.route('/ai/research', methods=['POST'])
def ai_research():
    data = request.json or {}
    user_id = data.get('user_id')
    query = data.get('query', '')
    
    prompt = f"Provide actionable research and insider guidance for a woman planning: {query}."
    research = call_gpt_nano(prompt)
    return jsonify({'success': True, 'research': research})

@app.route('/user/<user_id>/daily-challenge', methods=['GET'])
def get_daily_challenge(user_id):
    challenges = [
        {'title': 'Research One Destination', 'description': 'Spend 15 minutes exploring accommodations or flights for a dream trip.'},
        {'title': 'Practice Your Power Pose', 'description': 'Spend 2 minutes standing tall before your next goal-setting session.'},
        {'title': 'Set a Micro-Savings Goal', 'description': 'Transfer $5 or $10 to a dream savings envelope.'},
        {'title': 'Send One Outreach Message', 'description': 'Connect with someone already living the dream you are pursuing.'},
    ]
    day = datetime.utcnow().timetuple().tm_yday
    return jsonify({'success': True, 'challenge': challenges[day % len(challenges)]})

# ==========================================
# CHALLENGES & WINS
# ==========================================
@app.route('/challenges', methods=['GET'])
def get_challenges():
    conn = get_db()
    c = conn.cursor()
    items = c.execute("SELECT * FROM challenges").fetchall()
    conn.close()
    return jsonify({
        'success': True,
        'challenges': [
            {
                'id': str(r['id']),
                'title': r['title'],
                'description': r['description'],
                'category': r['category'],
                'duration_days': r['duration_days'],
                'participant_count': r['participant_count'],
                'daily_tasks': [],
                'is_active': False,
                'start_date': None
            } for r in items
        ]
    })

@app.route('/user/<user_id>/challenges/<challenge_id>/join', methods=['POST'])
def join_challenge(user_id, challenge_id):
    conn = get_db()
    c = conn.cursor()
    c.execute("""
        INSERT INTO user_challenges (user_id, challenge_id, start_date, is_active)
        VALUES (?, ?, ?, 1)
    """, (user_id, challenge_id, datetime.utcnow().isoformat()))
    c.execute("UPDATE challenges SET participant_count = participant_count + 1 WHERE id = ?", (challenge_id,))
    conn.commit()
    conn.close()
    return jsonify({'success': True, 'message': 'Challenge joined!'})

@app.route('/user/<user_id>/wins', methods=['GET', 'POST'])
def handle_wins(user_id):
    conn = get_db()
    c = conn.cursor()
    if request.method == 'POST':
        data = request.json or {}
        c.execute("""
            INSERT INTO wins (user_id, title, description, category, achieved_at)
            VALUES (?, ?, ?, ?, ?)
        """, (user_id, data.get('title'), data.get('description', ''), data.get('category'), datetime.utcnow().isoformat()))
        c.execute("UPDATE users SET total_wins = total_wins + 1 WHERE id = ?", (user_id,))
        conn.commit()
        conn.close()
        return jsonify({'success': True, 'message': 'Win logged!'})
    else:
        wins = c.execute("SELECT * FROM wins WHERE user_id = ? ORDER BY id DESC", (user_id,)).fetchall()
        conn.close()
        return jsonify({
            'success': True,
            'wins': [
                {
                    'id': str(w['id']),
                    'title': w['title'],
                    'description': w['description'],
                    'category': w['category'],
                    'achieved_at': w['achieved_at'],
                    'image_url': w['image_url'] or ''
                } for w in wins
            ]
        })

# ==========================================
# ADMIN, POLICIES & HEALTH
# ==========================================
@app.route('/admin')
def admin_dashboard():
    if request.args.get('key') != ADMIN_KEY:
        return jsonify({'error': 'Unauthorized'}), 401

    conn = get_db()
    c = conn.cursor()
    users = c.execute("SELECT id, email, tier, trials, created_at FROM users ORDER BY id DESC").fetchall()
    conn.close()

    rows = "".join([f"""
        <tr>
            <td style='padding:12px; border-bottom:1px solid #eee;'>{u['id']}</td>
            <td style='padding:12px; border-bottom:1px solid #eee; font-weight:600;'>{u['email']}</td>
            <td style='padding:12px; border-bottom:1px solid #eee;'>
                <span style='background:#FCE7F3; color:#BE185D; padding:4px 10px; border-radius:12px; font-size:12px; font-weight:bold;'>
                    {(u['tier'] or 'FREE').upper()}
                </span>
            </td>
            <td style='padding:12px; border-bottom:1px solid #eee;'>{u['trials']}</td>
            <td style='padding:12px; border-bottom:1px solid #eee; color:#64748b;'>{u['created_at']}</td>
        </tr>
    """ for u in users])

    return f"""
    <!DOCTYPE html>
    <html>
    <head>
        <title>PacksLight - Admin Dashboard</title>
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
            body {{ font-family: -apple-system, sans-serif; background: #fdf2f8; padding: 30px; }}
            .card {{ background: white; border-radius: 16px; box-shadow: 0 4px 6px rgba(0,0,0,0.05); max-width: 800px; margin: auto; overflow: hidden; }}
            .header {{ background: #E91E63; color: white; padding: 24px; }}
            table {{ width: 100%; border-collapse: collapse; text-align: left; }}
            th {{ background: #fdf2f8; padding: 14px; font-size: 13px; color: #831843; }}
        </style>
    </head>
    <body>
        <div class="card">
            <div class="header">
                <h2 style="margin:0;">PacksLight - Registered Users ({len(users)})</h2>
                <p style="margin:6px 0 0; opacity:0.85; font-size:13px;">Engine: Microsoft Foundry ({AI_MODEL}) | DB: SQLite (WAL Active)</p>
            </div>
            <table>
                <thead>
                    <tr><th>ID</th><th>Email</th><th>Tier</th><th>Trials Left</th><th>Joined</th></tr>
                </thead>
                <tbody>
                    {rows if rows else "<tr><td colspan='5' style='padding:24px; text-align:center;'>No users registered yet.</td></tr>"}
                </tbody>
            </table>
        </div>
    </body>
    </html>
    """

@app.route('/delete-account')
def delete_account_info():
    return """
    <!DOCTYPE html>
    <html>
    <head><meta charset="UTF-8"><title>PacksLight - Delete Account</title></head>
    <body style="font-family:sans-serif; padding:40px; max-width:600px; margin:auto; line-height:1.6; color:#222;">
        <h2>PacksLight - Account & Data Deletion</h2>
        <p>To delete your PacksLight account, dream roadmaps, wins journal, and all associated habit data, please send an email to <b>support@presentmeapp.xyz</b> with the subject 'Delete Account'.</p>
        <p>Your request will be processed, and all stored data will be permanently removed within 30 days.</p>
    </body>
    </html>
    """

@app.route("/privacy")
def privacy_policy():
    return """
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Privacy Policy - PacksLight</title>
        <style>
            body { font-family: -apple-system, sans-serif; line-height: 1.6; max-width: 800px; margin: 0 auto; padding: 30px; color: #222; background: #fdf2f8; }
            h1, h2 { color: #E91E63; }
            .card { background: white; padding: 30px; border-radius: 12px; box-shadow: 0 2px 8px rgba(0,0,0,0.06); }
        </style>
    </head>
    <body>
        <div class="card">
            <h1>Privacy Policy for PacksLight</h1>
            <p><strong>Effective Date:</strong> September 2026</p>
            <p>PacksLight ("we", "our", or "us") provides tools to turn big dreams into daily micro-actions. This Privacy Policy details our data collection and protection practices.</p>
            <h2>1. Information We Collect</h2>
            <p>• <strong>Personal Info:</strong> Email address for authentication and profile management.</p>
            <p>• <strong>Dreams & Habits:</strong> Goal descriptions, milestones, streak counters, and wins logged within the app.</p>
            <p>• <strong>Purchase History:</strong> Managed securely through Google Play Billing and RevenueCat to unlock coaching credits and subscriptions.</p>
            <h2>2. Third-Party Services</h2>
            <p>We work with Google Play Services (billing), Microsoft Foundry AI (dream action planning), and RevenueCat (in-app subscription management).</p>
            <h2>3. Data Deletion & Contact</h2>
            <p>To request permanent deletion of your account and goal data, contact us at <strong>support@presentmeapp.xyz</strong>.</p>
        </div>
    </body>
    </html>
    """

@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({
        'status': 'healthy',
        'service': 'PacksLight API',
        'engine': AI_MODEL,
        'timestamp': datetime.utcnow().isoformat()
    })

if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0', port=5000)