module IODemon
	class Subscriber
		include IODemon::Rack::Responses		
		attr_accessor :subcription, :deferrable_response, :redis

		def initialize(redis)
			@redis = redis
			@deferrable_response = IODemon::DeferrableResponse.new
		end

		# env contains parameters
		# Accepts the environment variables, parses the headers
		# Identifies and subscribes to the channel and returns a 202 accepted
		# On successful subscription activate on message callbacks which should return a deferred respose Async.callback
		def respond(env)
			@env = env			
			request = ::Rack::Request.new(@env)			
			channel = request.params["channel"]
			puts "*" * 50
			puts "Channel: #{channel}"
			puts "*" * 50
			return IODemon::Rack::Responses::NOT_ACCEPTABLE unless channel.present?
			unique_hash = IODemon::Hasher.hashify
			subscribe(channel, unique_hash)
			throw :async
			#generate_response(:accepted, unique_hash)
		end

		private

		def subscribe(channel = "/home", unique_hash)
			channel_name = "#{channel}.#{unique_hash}"
			@subscription = @redis.subscribe(channel_name)

			@subscription.callback{ |x|
				#Success
				# Create a new class. Create a message queue
				puts "Subscription to #{channel} successful"
				EM.next_tick { 
					puts "Sending async callback.."
					#@env['async.callback'].call([200, {'Content-Type' => 'text/plain'}, @deferrable_response])
				}
				IODemon::Queue.new(channel, unique_hash, self)
			}

			@subscription.errback{|err| 
				EM.next_tick { raise err }
			}

			@redis.on(:message) do |channel, message|
				# On message 
				# push the message into the appropriate queue
				puts "#{channel}: #{message}"
			end
		end
	end
end