Простой REST API на Flask с диагностикой сервера, упаковкой в Docker и готовым Compose.

<b>Локальный запуск</b>

python -m venv venv
pip install -r app/requirements.txt
python app/main.py
Сервер: http://localhost:5000

<b>Доступные эндпоинты:</b>

GET / → {"message":"Hello, World!"}

GET /health → {"status":"ok"}

GET /api/users → список пользователей

POST /api/users → создать (поля: name, email)

GET /api/users/<id> → получить пользователя

DELETE /api/users/<id> → удалить


<b>Тесты</b>

pytest app/tests/test_app.py -v

Скрипт диагностики</b>

chmod +x scripts/server-info.sh

./scripts/server-info.sh [URL1] [URL2] ...

Пример:

./scripts/server-info.sh http://localhost:5000/health https://google.com

Выводит системную информацию, ресурсы, Docker-контейнеры и проверяет доступность указанных сервисов.
Лог пишется в server-info.log. Возвращает 1, если хотя бы один сервис недоступен.


<b>Docker</b>

docker build -t simple-app:latest.

docker run -d -p 5000:5000 --name simple-app simple-app:latest

curl http://localhost:5000/health


<b>Docker Compose</b>

docker-compose up -d

docker-compose ps

docker-compose logs -f app

docker-compose down

Приложение доступно на http://localhost:5000.

Переменные окружения заданы в docker-compose.yml.
