require "sinatra"
require "net/http"

#set :bind, "0.0.0.0"

get "/" do
  "Hello world!"
end

post "/complaint" do
  address_to_unsubscribe = params["message"].scan(/To:\s?.*\<(.*)\>/).flatten.last

  if address_to_unsubscribe
    complaint_hash = complaint_hash_for(address_to_unsubscribe)
    response = post_to_identity(complaint_hash.to_json)
    "#{response.code} - Posted complaint for #{address_to_unsubscribe}"
  end
end

post "/json" do
  json_blob = params["message"].match(/({.*})/m)

  if json_blob
    response = post_to_identity(json_blob[0])
    "#{response.code} Forwarded json to /feedback-loop"
  end
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
  uri = URI("https://identity.degoedezaak.org/mailings/api/mailings/feedback-loop")
  # uri = URI("https://postb.in/jgPQ5CC1")

  https = Net::HTTP.new(uri.host, uri.port)
  https.use_ssl = true

  headers = {
    "Content-Type" => "application/json",
  }
  request = Net::HTTP::Post.new(uri.path, headers)
  request.body = json_payload

  https.request(request)
end
