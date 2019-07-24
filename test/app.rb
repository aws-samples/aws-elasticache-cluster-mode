#
# Executes operations against Redis cluster, logging response times.
#

require 'redis'
require 'redis/distributed'
require 'redis/connection/hiredis'

require 'benchmark'
require 'securerandom'
require 'faker'
require 'json'

REDIS_ENDPOINT = ENV['ELASTICACHE_ENDPOINT']
REDIS_PORT = ENV['ELASTICACHE_PORT'].to_i

SESSION_KEY = 'session_'

@redis = nil

def write_data(session_id)
  name = Faker::Name.name
  email = Faker::Internet.email
  ip_address = Faker::Internet.ip_v4_address
  company = Faker::Company.name
  job = Faker::Job.title

  Benchmark.measure {
    @redis.hmset(session_id,
               'name', name,
               'email', email,
               'ip_address', ip_address,
               'company', company,
               'job', job)
  }
end

def read_data(session_id)
  Benchmark.measure {
    @redis.hgetall(session_id).to_json
  }
end

def log_result(request_id, connection_result, write_result, read_result)
  msg = {
    type: 'ECL',
    requestId: request_id,
    connection: connection_result.real,
    write: write_result.real,
    read: read_result.real
  }
  puts msg.to_json
end

def handler(event:, context:)
  p "Caller Request ID: #{event['request_id']}" if !event['request_id'].nil?

  begin
    connection_result = Benchmark.measure {
      # create a new connection to the cluster on every call
      @redis = Redis.new(cluster: ["redis://#{REDIS_ENDPOINT}"])
    }

    uuid = SecureRandom.uuid
    session_id = "#{SESSION_KEY}:#{uuid}"

    write_data = write_data(session_id)
    read_data = read_data(session_id)

    log_result(context.aws_request_id, connection_result, write_data, read_data)
  rescue Error => e
    msg = {
      type: 'ECL-ERROR',
      timestamp: Time.now.strftime('%Y-%m-%dT%H:%M:%S.%L%:z'),
      requestId: request_id,
      error: e.message
    }
    p msg.to_json
    return { error: e.message }
  end

  {
    statusCode: 200,
    statusDescription: '200 Ok',
    isBase64Encoded: false,
    headers: {
      'Content-Type': 'application/json'
    },
    body: { write: write_data, read: read_data }.to_json
  }
end