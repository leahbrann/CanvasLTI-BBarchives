require 'sinatra'
require 'dotenv'
require 'ims/lti'
require 'oauth/request_proxy/rack_request'
require 'sinatra/activerecord'
require 'uri'
require 'net/http'
require './environments'

Dotenv.load

enable :sessions
set :protection, :except => :frame_options

OAUTH_10_SUPPORT = true

class Course < ActiveRecord::Base
  def archiveurl
    "#{ENV['ARCHIVE_FILE_PATH']}#{self.course_id}.zip"
  end
  
  def downloadexists?
    uri = URI("#{self.archiveurl}")

    request = Net::HTTP.new(uri.host, uri.port)
    response= request.request_head uri.path
    response.code.to_i == 200
  end
  
end


# the consumer keys/secrets
$oauth_creds = {"#{ENV['APPKEY']}" => "#{ENV['APPSECRET']}"}

def show_error(message)
  @message = message
end

def authorize!
  if key = params['oauth_consumer_key']
    if secret = $oauth_creds[key]
      @tp = IMS::LTI::ToolProvider.new(key, secret, params)
    else
      @tp = IMS::LTI::ToolProvider.new(nil, nil, params)
      @tp.lti_msg = "Your consumer didn't use a recognized key."
      show_error "Consumer key wasn't recognized"
      return false
    end
  else
    show_error "No consumer key"
    return false
  end

  if !@tp.valid_request?(request)
    show_error "The OAuth signature was invalid"
    return false
  end

  if Time.now.utc.to_i - @tp.request_oauth_timestamp.to_i > 60*60
    show_error "Your request is too old."
    return false
  end

  # save the launch parameters for use in later request
  session['launch_params'] = @tp.to_params

  @username = @tp.username

  return true
end


get '/' do
	erb :index
end

# The url for launching the tool
# It will verify the OAuth signature
post '/lti_tool' do
  return erb :error unless authorize!

     # normal tool launch without grade write-back
    signature = OAuth::Signature.build(request, :consumer_secret => @tp.consumer_secret)

    @signature_base_string = signature.signature_base_string
    @secret = signature.send(:secret)
  
  @Instructor = params['custom_canvas_user_login_id']
  courses = (Course.where instructor_id: @Instructor).distinct.order(:course_id)
    if courses
      @archivedcourses =  courses.select{|course| course.downloadexists?}
    end
    
  erb :blackboardarchive

end

post '/signature_test' do
  erb :proxy_setup
end

post '/proxy_launch' do
  uri = URI.parse(params['launch_url'])

  if uri.port == uri.default_port
    host = uri.host
  else
    host = "#{uri.host}:#{uri.port}"
  end

  consumer = OAuth::Consumer.new(params['lti']['oauth_consumer_key'], params['oauth_consumer_secret'], {
      :site => "#{uri.scheme}://#{host}",
      :signature_method => "HMAC-SHA1"
  })

  path = uri.path
  path = '/' if path.empty?

  @lti_params = params['lti'].clone
  if uri.query != nil
    CGI.parse(uri.query).each do |query_key, query_values|
      unless @lti_params[query_key]
        @lti_params[query_key] = query_values.first
      end
    end
  end

  path = uri.path
  path = '/' if path.empty?

  proxied_request = consumer.send(:create_http_request, :post, path, @lti_params)
  signature = OAuth::Signature.build(proxied_request, :uri => params['launch_url'], :consumer_secret => params['oauth_consumer_secret'])

  @signature_base_string = signature.signature_base_string
  @secret = signature.send(:secret)
  @oauth_signature = signature.signature

  erb :proxy_launch
end

get '/tool_config.xml' do
  host = request.scheme + "://" + request.host_with_port
  url = (params['signature_proxy_test'] ? host + "/signature_test" : host + "/lti_tool")
  tc = IMS::LTI::ToolConfig.new(:title => "Blackboard Archives", :launch_url => url)
  tc.description = "Provides access to instructor Blackboard archives."
  tc.set_ext_params("canvas.instructure.com", {"privacy_level" => "public"})
  tc.set_ext_param("canvas.instructure.com", "user_navigation", {"enabled" => "true", "text" => "Blackboard Archives"})
  headers 'Content-Type' => 'text/xml'
  tc.to_xml(:indent => 4)
end
