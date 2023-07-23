require "open-uri"
require "openssl"
require "pathname"
require "socket"
require "uri"

class NotFound < StandardError; end
class Forbidden < StandardError; end

port = 8888
server = TCPServer.new(port)
options = {}
ARGV.each do |arg|
  case arg
  when "--server", "-s"
    options[:server] = true
  when "--proxy", "-p"
    options[:proxy] = true
  when "--help", "-h"
    print "Usage: fetchd [--server] [--proxy]"
    exit
  end
end

loop do
  Thread.start(server.accept) do |client|
    response_code = 200
    response_size = 0
    begin
      request = client.gets.chomp
      sock_domain, remote_port, remote_hostname, remote_ip = client.peeraddr
      action, url = request.split
      uri = URI.parse(url)
      case uri.scheme
      when "http", "https"
        raise Forbidden unless options[:proxy]
        begin
          URI.open(url) do |file|
            response = file.read
            response_size = response.size
            client.puts response
          end
        rescue OpenURI::HTTPError
          raise NotFound
        end
      when "gemini"
        raise Forbidden unless options[:proxy]
        host = uri.host
        loop do
          tcp_socket = TCPSocket.new(host, 1965)
          context = OpenSSL::SSL::SSLContext.new
          context.verify_mode = OpenSSL::SSL::VERIFY_NONE
          ssl_socket = OpenSSL::SSL::SSLSocket.new(tcp_socket, context)
          ssl_socket.hostname = host
          ssl_socket.sync_close = true
          ssl_socket.connect
          ssl_socket.write("#{url}\r\n")
          headers = ssl_socket.gets&.chomp&.split.to_a
          response = ssl_socket.read
          ssl_socket.close
          tcp_socket.close
          case headers[0]
          when "31"
            url = headers[1]
          when "20"
            response_size = response.size
            client.puts response
            break
          else
            raise NotFound
          end
        rescue SocketError
          raise NotFound
        end
      when "gopher"
        raise Forbidden unless options[:proxy]
        host = uri.host
        path = uri.path.sub(/^\/\d+/, "")
        begin
          socket = TCPSocket.new(host, 70)
          socket.write("#{path}\r\n")
          response = socket.read
          response_size = response.size
          client.puts response
        rescue SocketError
          raise NotFound
        end
      when nil
        raise Forbidden unless options[:server]
        host = uri.host
        path = ".#{uri.path}"
        base = Pathname.new(Dir.pwd)
        begin
          if base.join(path).relative_path_from(base).to_s.start_with?("..")
            raise Forbidden
          elsif File.directory?(path)
            found = %w[index.html index.txt index.md].any? do |index|
              file = base.join(path, index)
              if File.exist?(file)
                response = File.read(file)
                response_size = response.size
                client.puts response
                true
              end
            end
            raise NotFound unless found
          else
            response = File.read(path)
            response_size = response.size
            client.puts response
          end
        end
        true
      end
    rescue NotFound, Errno::ENOENT
      response_code = 404
    rescue Forbidden
      response_code = 403
    end
    puts [remote_ip, "-", "-", request, response_code, response_size].join(" ")
    client.close
  end
end
