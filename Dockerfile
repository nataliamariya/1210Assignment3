FROM public.ecr.aws/o0z2l8w8/python:latest

WORKDIR /app

COPY requirements.txt requirements.txt

RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 5000

CMD ["python", "FlaskApp.py"]
