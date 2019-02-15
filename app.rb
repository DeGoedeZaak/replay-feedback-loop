require "sinatra"
require "net/http"
require "json"

#set :bind, "0.0.0.0"

get "/" do
  "Hello world!"
end

post "/complaint" do
  address_to_unsubscribe = params["message"].to_s.scan(/To:.*?([0-9a-z]+@[0-9a-z]+\.[a-z]+)/).flatten.last

  if address_to_unsubscribe
    complaint_hash = complaint_hash_for(address_to_unsubscribe)
    response = post_to_identity(complaint_hash.to_json)
    message = "#{response.code} - Posted complaint for #{address_to_unsubscribe}"
    logger.info message
    message
  end
end

post "/json" do
  json_blob = params["message"].match(/({.*})/m)

  if json_blob
    cleaned_json = json_blob[0].gsub(/\s+/, "")

    begin
      parsed_json = JSON.parse cleaned_json
      response = post_to_identity(parsed_json.to_json)
    rescue
      notification_type = extract_from_string(cleaned_json, "notificationType")
      email = extract_from_string(cleaned_json, "emailAddress")
      bounce_type = extract_from_string(cleaned_json, "bounceType")
      bounce_subtype = extract_from_string(cleaned_json, "bounceSubType")

      payload = case notification_type
      when "Bounce"
        bounce_hash_for(email, bounce_type, bounce_subtype)
      when "Complaint"
        complaint_hash_for(email)
      else {}
      end

      logger.info "found #{notification_type}: email: #{email} | bounceType: #{bounce_type} | bounceSubType: #{bounce_subtype}"
      response = post_to_identity(payload.to_json)
    end

    message = "#{response.code} Forwarded json to /feedback-loop"
    logger.info message
    message
  end
end

def extract_from_string(string, key)
  string.match(/\"#{key}\":\"(.*?)\"/)[1]
end

def bounce_hash_for(email, bounce_type = "Permanent", bounce_subtype = "General")
  {
    notificationType: "Bounce",
    bounce: {
      bounceType: bounce_type,
      bounceSubType: bounce_subtype,
      bouncedRecipients: [
        {
          emailAddress: email
        }
      ],
      timestamp: Time.now.strftime("%FT%T.%LZ")
    },
    mail: {
        messageId: "1234foo"
    }
  }
end

def complaint_hash_for(email)
  {
    notificationType: "Complaint",
    complaint: {
      complainedRecipients: [
        {
          emailAddress: email
        }
      ],
      timestamp: Time.now.strftime("%FT%T.%LZ")
    },
    mail: {
      messageId: "1234foo"
    }
  }
end

def post_to_identity(json_payload)
  uri = URI("#{IDENTITY_URL}/mailings/api/mailings/feedback-loop")

  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true if uri.scheme == "https"
  headers = {
    "Content-Type" => "application/json",
  }
  request = Net::HTTP::Post.new(uri.path, headers)
  request.body = json_payload

  http.request(request)
end
