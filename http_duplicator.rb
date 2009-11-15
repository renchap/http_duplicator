require 'rubygems'
require 'eventmachine'
require 'socket'

module HTTP_Duplicator
  def receive_data data
    backends = [
      { :host => 'localhost', :port => 10001 },
      { :host => 'localhost', :port => 10002 },
    ]
    p data
    puts "Sending to backends..."
    backends.each do |backend|
      puts "Backend #{backend[:host]}:#{backend[:port]}..."
      s = TCPSocket.open(backend[:host], backend[:port])
      s.puts data
      s.close
      puts "Done"
    end
    puts "All done"
  end
end

EventMachine::run do
  EventMachine::start_server '127.0.0.1', 10000, HTTP_Duplicator
end
