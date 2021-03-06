require 'socket'
require 'selenium-webdriver'
class  Applitools::Driver

  include Selenium::WebDriver::DriverExtensions::HasInputDevices

  attr_reader :remote_server_url, :remote_session_id, :screenshot_taker, :eyes
  attr_accessor :driver

  DRIVER_METHODS = [
    :title, :execute_script, :execute_async_script, :quit, :close, :get,
    :post, :page_source, :window_handles, :window_handle, :switch_to, 
    :navigate, :manage, :capabilities, :current_url
  ]

  ## If driver is not provided, Applitools::Driver will raise an EyesError exception.
  #
  def initialize(eyes, options)
    @driver = options[:driver]
    @eyes = eyes
    @remote_server_url = address_of_remote_server
    @remote_session_id = remote_session_id
    begin
      #noinspection RubyResolve
      if driver.capabilities.takes_screenshot?
       @screenshot_taker = false
      else
        @screenshot_taker = Applitools::ScreenshotTaker.new(@remote_server_url, @remote_session_id)
      end
    rescue => e 
      raise Applitools::EyesError.new "Can't take screenshots (#{e.message})"
    end
  end

  DRIVER_METHODS.each do |method|
    define_method method do |*args, &block|
      driver.send(method,*args, &block)
    end
  end

  def screenshot_as(output_type)
    return driver.screenshot_as(output_type) if !screenshot_taker

    if output_type.downcase.to_sym != :base64
      raise Applitools::EyesError.new("#{output_type} ouput type not supported for screenshot")
    end
    screenshot_taker.screenshot
  end 

  def mouse
    Applitools::EyesMouse.new(self, driver.mouse)
  end

  def keyboard
    Applitools::EyesKeyboard.new(self, driver.keyboard)
  end

  FINDERS = {
          :class             => 'class name',
          :class_name        => 'class name',
          :css               => 'css selector',
          :id                => 'id',
          :link              => 'link text',
          :link_text         => 'link text',
          :name              => 'name',
          :partial_link_text => 'partial link text',
          :tag_name          => 'tag name',
          :xpath             => 'xpath',
        }

  def find_element(*args)
    how, what = extract_args(args)

    # Make sure that "how" is a valid locator.
    unless FINDERS[how.to_sym]
      raise ArgumentError, "cannot find element by #{how.inspect}"
    end

    Applitools::Element.new(self, driver.find_element(how, what))
  end

  def find_elements(*args)
    how, what = extract_args(args)

    unless FINDERS[how.to_sym]
      raise ArgumentError, "cannot find element by #{how.inspect}"
    end

    driver.find_elements(how, what).map { |el| Applitools::Element.new(self, el) }
  end

  def ie?
    driver.to_s == 'ie'
  end

  def firefox?
    driver.to_s == 'firefox'
  end

  def user_agent
    execute_script 'return navigator.userAgent'
  rescue => e
    EyesLogger.info "getUserAgent(): Failed to obtain user-agent string (#{e.message})"
  end

  private

    def address_of_remote_server
      # The driver's url is not available using a standard interface, so we use reflection to get it.
      #noinspection RubyResolve
      uri = URI(driver.instance_eval{@bridge}.instance_eval{@http}.instance_eval{@server_url})
      raise Applitools::EyesError.new('Failed to get remote web driver url') if uri.to_s.empty?

      webdriver_host = uri.host
      if %w[127.0.0.1 localhost].include?(webdriver_host) && !firefox? && !ie?
        uri.host = get_local_ip || 'localhost'
      end

      uri
    end

    def remote_session_id
      driver.remote_session_id
    end

    def get_local_ip
      begin
        Socket.ip_address_list.detect do |intf|
          intf.ipv4? and !intf.ipv4_loopback? and !intf.ipv4_multicast?
        end.ip_address
      rescue SocketError => e
        raise Applitools::EyesError.new("Failed to get local IP! (#{e})")
      end
    end

    def extract_args(args)
      case args.size
      when 2
        args
      when 1
        arg = args.first

        unless arg.respond_to?(:shift)
          raise ArgumentError, "expected #{arg.inspect}:#{arg.class} to respond to #shift"
        end

        # this will be a single-entry hash, so use #shift over #first or #[]
        arr = arg.dup.shift
        unless arr.size == 2
          raise ArgumentError, "expected #{arr.inspect} to have 2 elements"
        end

        arr
      else
        raise ArgumentError, "wrong number of arguments (#{args.size} for 2)"
      end
    end

end

## .bridge, .session_id and .server_url are private methods in Selenium::WebDriver gem
module Selenium::WebDriver
  class Driver
    def remote_session_id
      bridge.session_id
    end
  end

  class Remote::Http::Common
    def get_server_url
      server_url
    end
  end
end
