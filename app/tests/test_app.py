import pytest
from app.main import app, users, next_id

@pytest.fixture(autouse=True)
def clean_db():
    """Очищает хранилище перед каждым тестом."""
    users.clear()
    # Сбрасываем next_id на 1
    # Используем глобальную переменную из модуля app.main
    import app.main as main_module
    main_module.next_id = 1

@pytest.fixture
def client():
    """Возвращает тестовый клиент Flask."""
    with app.test_client() as client:
        yield client

# Тест 1: GET /
def test_hello(client):
    response = client.get('/')
    assert response.status_code == 200
    assert response.json == {"message": "Hello, World!"}

# Тест 2: GET /health
def test_health(client):
    response = client.get('/health')
    assert response.status_code == 200
    assert response.json == {"status": "ok"}

# Тест 3: GET /api/users (пустой список)
def test_get_users_empty(client):
    response = client.get('/api/users')
    assert response.status_code == 200
    assert response.json == {"users": []}

# Тест 4: POST /api/users успешное создание
def test_create_user_success(client):
    data = {"name": "Alice", "email": "alice@example.com"}
    response = client.post('/api/users', json=data)
    assert response.status_code == 201
    assert response.json["name"] == "Alice"
    assert response.json["email"] == "alice@example.com"
    assert "id" in response.json
    # Проверка, что пользователь добавлен
    get_resp = client.get('/api/users')
    assert len(get_resp.json["users"]) == 1

# Тест 5: POST /api/users ошибка валидации (пропущено поле email)
def test_create_user_missing_field(client):
    data = {"name": "Bob"}
    response = client.post('/api/users', json=data)
    assert response.status_code == 400
    assert "error" in response.json
    assert "Missing fields" in response.json["error"]
    # Убедимся, что пользователь не создан
    get_resp = client.get('/api/users')
    assert len(get_resp.json["users"]) == 0