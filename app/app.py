# -​*- coding: utf-8 -*​-

from flask import Flask
from flask import jsonify
from flask import make_response
from flask import Response
from flask import request
from flask import redirect
from flask import url_for

from confluent_kafka import Consumer, KafkaError
import json

app = Flask(__name__)


@app.after_request
def add_header(response):
    response.cache_control.no_cache = True
    return response


def get_kafka_client():
    c = Consumer({'bootstrap.servers': 'kafka:9092', 'group.id': 'twitter.streaming', 'default.topic.config': {'auto.offset.reset': 'largest'}})
    c.subscribe(['Twitter.processed'])
    return c


@app.route('/stream')
def streamed_response():
    client = get_kafka_client()
    if request.headers.get('accept') == 'text/event-stream':
        def generate():
            running = True
            while running:
                msg = client.poll()
                if not msg.error():
                    message = json.loads(msg.value().decode('utf-8'))
                    yield 'data: {0}\n\n'.format(message['tweet'])
                elif msg.error().code() != KafkaError._PARTITION_EOF:
                    yield msg.error()
                    running = False
        return Response(generate(), content_type='text/event-stream')
    return redirect(url_for('static', filename='index.html'))


@app.route('/_status', methods=['GET'])
def get_status():
    response = {'message': 'OK ', 'status': 200}
    return make_response(jsonify(response), 200)


@app.errorhandler(401)
def not_authorized(error):
    return make_response(jsonify({"message": "Not Authorized", "status": 401}), 401)


@app.errorhandler(404)
def not_found(error):
    return make_response(jsonify({"message": "Resource not found", "status": 404}), 404)


@app.errorhandler(405)
def method_not_allowed(error):
    return make_response(jsonify({"message": "Method Not Allowed", "status": 405}), 405)


@app.errorhandler(500)
def internal_error(error):
    app.logger.error(error)
    return make_response(jsonify({"message": "Internal error", "status": 500}), 500)


@app.errorhandler(Exception)
def unhandled_exception(error):
    app.logger.exception('Unhandled Exception')
    return make_response(jsonify({"message": "Internal error", "status": 500}), 500)


if __name__ == '__main__':
    app.run(debug=True, host='0.0.0.0')
