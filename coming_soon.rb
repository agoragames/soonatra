require 'rubygems'
require 'sinatra/base'
require 'haml'
require 'sass'
require 'compass'
require 'split'
require 'hominid'
require 'feedzirra'
require 'hoptoad_notifier'
require 'uri'
require 'csv'

CSVKLASS = CSV

def load_configuration(file, name)
  if !File.exist?(file)
    puts "There's no configuration file at #{file}!"
    exit!
  end
  const_set(name, YAML.load_file(file))
end

class SplitGroup
  attr_accessor :splits

  def initialize
    @splits = []
  end

  def add(test_name)
    @splits << test_name
    test_name
  end
end

class ComingSoon < Sinatra::Base
  enable :sessions
  helpers Split::Helper

  configure do
    load_configuration('config/config.yml', 'APP_CONFIG')

    if APP_CONFIG['hoptoad_api_key']
      HoptoadNotifier.configure do |config|
        config.api_key = APP_CONFIG['hoptoad_api_key']
      end
      use HoptoadNotifier::Rack
      enable :raise_errors
    end

    DataMapper.setup(:default, {
      :adapter  => 'redis',
      :user     => APP_CONFIG['redis']['user'],
      :password => APP_CONFIG['redis']['password'],
      :host     => APP_CONFIG['redis']['host'],
      :port     => APP_CONFIG['redis']['port']
    })

    user     = APP_CONFIG['redis']['user']
    password = APP_CONFIG['redis']['password']
    host     = APP_CONFIG['redis']['host']
    port     = APP_CONFIG['redis']['port']
    Split.redis = "redis://#{user}:#{password}@#{host}:#{port}/"

    redis_app_name = APP_CONFIG['app_name'].gsub(' ', '_').downcase
    Split.redis.namespace = "split:soonatra:#{redis_app_name}"

    Compass.configuration do |config|
      config.project_path = File.dirname(__FILE__)
      config.css_dir = 'tmp/stylesheets'
      config.sass_dir = 'views'
      config.http_path = '/'
    end

    set :haml, { :format => :html5 }
    set :sass, Compass.sass_engine_options
    set :root, File.dirname(__FILE__)
  end

  before do
    @app_name  = APP_CONFIG['app_name']
    @splits = SplitGroup.new
    File.read('views/themes/_current_theme.sass').scan(/@import themes\/(.*)/)
    @app_theme = $1
    
    expires 60, :public, :'no-cache'
  end

  get '/stylesheets/:name.css' do
    content_type 'text/css', :charset => 'utf-8'
    sass(:"#{params[:name]}")
  end

  get '/' do
    protected! if APP_CONFIG['http_basic']
    flash_message(params[:m])

    @concepts = APP_CONFIG['concepts']
    @blog_posts = FeedzirraRedis::Entry.last(2)
    @features = APP_CONFIG['features']
    @intro = APP_CONFIG['intro']
    @signup = APP_CONFIG['signup']

    haml :index
  end

  post '/create' do
    protected! if APP_CONFIG['http_basic']
    @splits.splits.each { |test| finished(test) }

    if params[:email].blank?
      redirect '/?m=email_blank'
    elsif params[:email].match /^([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})$/i
      chimp = Hominid::API.new( APP_CONFIG['mailchimp']['api_key'] )
      list = chimp.find_list_by_name(APP_CONFIG['mailchimp']['list_name'])
      chimp.list_subscribe(list['id'], params[:email])
      redirect '/?m=success'
    else
      redirect '/?m=email_invalid'
    end
  end

  helpers do

    def flash_message(message)
      case message
      when 'email_blank'
        @notice = APP_CONFIG['flash_messages']['email_blank']
      when 'email_invalid'
        @notice = APP_CONFIG['flash_messages']['email_invalid']
      when 'success'
        @success = APP_CONFIG['flash_messages']['email_success']
      else ''
      end
    end

    def pluralize(count, singular, plural = nil)
      "#{count || 0} " + ((count == 1 || count =~ /^1(\.0+)?$/) ? singular : (plural || singular.pluralize))
    end

    def testing?
      ENV['RACK_ENV'] == 'test'
    end

    def protected!
      unless authorized?
        response['WWW-Authenticate'] = %(Basic realm="Authentication Required")
        throw(:halt, [401, "Not authorized\n"])
      end
    end

    def authorized?
      return true if testing?
      @auth ||=  Rack::Auth::Basic::Request.new(request.env)
      @auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == [APP_CONFIG['admin_username'], APP_CONFIG['admin_password']]
    end

    def email_signup(content_for)
      case content_for
      when :headline
        ab_test @splits.add('Email Signup Headline'), *APP_CONFIG['email_signup']['headlines']
      when :intro
        ab_test @splits.add('Email Signup Intro'), *APP_CONFIG['email_signup']['intros']
      when :call_to_action
        ab_test @splits.add('Email Signup Call To Action'), *APP_CONFIG['email_signup']['call_to_actions']
      when :image_button
        APP_CONFIG['email_signup']['image_button']
      end
    end

    def features(content_for)
      case content_for
      when :headline
        ab_test @splits.add('Features Headline'), *APP_CONFIG['features']['headlines']
      when :items
        APP_CONFIG['features']['items']
      when :empty
        APP_CONFIG['features']['empty']
      end
    end

    def feedback(content_for)
      case content_for
      when :headline
        ab_test @splits.add('Feedback Headline'), *APP_CONFIG['feedback']['headlines']
      when :intro
        ab_test @splits.add('Feedback Intro'), *APP_CONFIG['feedback']['intros']
      when :call_to_action
        ab_test @splits.add('Feedback Call To Action'), *APP_CONFIG['feedback']['call_to_actions']
      when :concepts
        APP_CONFIG['feedback']['concepts']
      when :empty
        APP_CONFIG['feedback']['empty']
      end
    end

    def blog(content_for)
      case content_for
      when :headline
        ab_test @splits.add('Blog Headline'), *APP_CONFIG['blog']['headlines']
      when :empty
        APP_CONFIG['blog']['empty']
      end
    end

    def footer(content_for)
      case content_for
      when :copyright
        APP_CONFIG['footer']['copyright']
      when :network
        APP_CONFIG['footer']['network']
      end
    end
    
    # ex: class => cycle(:even, :odd)
    def cycle(*args)
      @cycle_index ||= -1 # to start in 0
      @cycle_index = (@cycle_index >= args.size-1) ? 0 : @cycle_index + 1
      args[@cycle_index].to_s
    end

  end
end
