from flask import Flask, request, jsonify

app = Flask(__name__)

users = []
next_id = 1

@app.route('/', methods=['GET'])
def hello():
    return jsonify({"message": "Hello, World!"})

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "ok"}), 200

@app.route('/api/users', methods=['GET'])
def get_users():
    return jsonify({"users": users})

@app.route('/api/users', methods=['POST'])
def create_user():
    global next_id
    data = request.get_json()
    if not data:
        return jsonify({"error": "Invalid JSON"}), 400
    required = ['name', 'email']
    missing = [f for f in required if f not in data]
    if missing:
        return jsonify({"error": f"Missing fields: {', '.join(missing)}"}), 400
    user = {"id": next_id, "name": data["name"], "email": data["email"]}
    users.append(user)
    next_id += 1
    return jsonify(user), 201

@app.route('/api/users/<int:user_id>', methods=['GET'])
def get_user(user_id):
    user = next((u for u in users if u["id"] == user_id), None)
    if not user:
        return jsonify({"error": "User not found"}), 404
    return jsonify(user)

@app.route('/api/users/<int:user_id>', methods=['DELETE'])
def delete_user(user_id):
    global users
    user = next((u for u in users if u["id"] == user_id), None)
    if not user:
        return jsonify({"error": "User not found"}), 404
    users = [u for u in users if u["id"] != user_id]
    return jsonify({"message": "User deleted"}), 200

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)