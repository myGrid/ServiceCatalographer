require "net/ping"
include Net
class OnLooker
  
  def self.check(host, ping_type, debug=false, timeout=2)
    type = ping_type.downcase
    if type == "ip"
      request = Net::PingExternal.new(host, timeout)
      get_result(request, debug)
    elsif type == "web"
      request = PingTCP.new(host, "http", 2)
      get_result(request, debug)
    else
      "Type invalid. Try 'web' or 'ip'."
    end    
  end
  
  def self.get_result(request, debug)
    if request.ping?
        "Online"
    else
        status = "Offline "
        if debug == true
          return status + request.exception
        else
          return status
        end
    end
  end
  
end

module OnLookerHelper
  
  def onlooker_format(status, *params)
    options = params.extract_options!.symbolize_keys
    
    options[:online_img] ||= options.include?(:online_img)
    options[:offline_img] ||= options.include?(:offline_img)
    options[:unknown_img] ||= options.include?(:unknown_img)
    options[:default_img] ||= options.include?(:default_img)
    
    if status == "Online"
      options[:online_img]
      #"<img src='#{options[:online_img]}' alt='Online' />"
    elsif status == "Offline"
      options[:offline_img]
      #"<img src='#{options[:offline_img]}' alt='Offline' />"
    elsif status == "Unknown"
      options[:unknown_img]
      #"<img src='#{options[:offline_img]}' alt='Offline' />"
    else
      options[:default_img]
      #"<img src='#{options[:unknown_img]}' alt='Unknown' />"
    end
  end
  
end