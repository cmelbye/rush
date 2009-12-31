require 'rubygems'
require 'thin'

# Rack handler that translates the incoming HTTP request into a
# Rush::Connection::Local call.  The results are sent back across the wire to
# be decoded by Rush::Connection::Remote on the other side.
class RushHandler
  def call(env)
    req = Rack::Request.new(env)
    params = req.GET
    payload = req.body.read
    
    params.each do |k,v|
      params.delete(k)
      params[k.to_sym] = v if k.respond_to? :to_sym
    end
    
    without_action = params
    without_action.delete(params[:action])
    
    msg = sprintf("%-20s", params[:action])
    msg += without_action.inspect
    msg += " + #{payload.size} bytes of payload" if payload.size > 0
    log msg
    
    params[:payload] = payload
    
    begin
      result = box.connection.receive(params)
      response = result
    rescue Rush::Exception => e
      response = "#{e.class}\n#{e.message}\n"
    end
    
    [200, {'Content-Type' => 'text/plain'}, [response]]
  rescue Exception => e
    log e.full_display
  end
  
  def box
    @box ||= Rush::Box.new('localhost')
  end
  
  def log(msg)
    File.open('rushd.log', 'a') do |f|
      f.puts "#{Time.now.strftime('%Y-%m-%d %H:%I:%S')} :: #{msg}"
    end
  end
end

# A container class to run the Mongrel server for rushd.
class RushServer
	def run
		host = "127.0.0.1"
		port = Rush::Config::DefaultPort
    rushd = Rack::Builder.app do
      use Rack::Auth::Basic, "rushd" do |username, password|
        config = Rush::Config.new
        password == config.passwords[username]
      end
      
      run RushHandler.new
    end
    
    ::Thin::Logging.silent = true
    Rack::Handler::Thin.run(rushd, :Host => host, :Port => port)
    rushd.log "rushd listening on #{host}:#{port}"
	end
end

class Exception
	def full_display
		out = []
		out << "Exception #{self.class} => #{self}"
		out << "Backtrace:"
		out << self.filtered_backtrace.collect do |t|
			"   #{t}"
		end
		out << ""
		out.join("\n")
	end

	def filtered_backtrace
		backtrace.reject do |bt|
			bt.match(/^\/usr\//)
		end
	end
end
