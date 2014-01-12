require "bundler"
Bundler.setup

require "sinatra"
require "fog"
require "mime/types"
require "uri"

SIXTYTWO = ("0".."9").to_a + ("a".."z").to_a + ("A".."Z").to_a

class S3MediaUploader < Sinatra::Base
  configure do
    if ENV["HTTP_USER"] && ENV["HTTP_PASS"]
      use Rack::Auth::Basic, "Restricted Area" do |username, password|
        [username, password] == [ENV["HTTP_USER"], ENV["HTTP_PASS"]]
      end
    end
  end

  get '/' do
    erb :index, :locals => {message: "Nothing to see here."}
  end

  get "/tweetbot/*" do
    # Increment counter
    counter_filename = "/s/counter.txt"
    begin
      counter_file = bucket.files.get(counter_filename)
      counter = counter_file.body.to_i + 1
      counter_file.body = counter
      counter_file.save
    rescue
      counter = 1
      counter_file = bucket.files.create(
        :key => counter_filename,
        :body   => counter,
        :public => false
      )
    end

    # Generate
    upload_key = generate_key counter

    retries = 0
    begin
      media = params["media"]
      filename = "#{b62ts}#{File.extname(media[:filename])}"
      content_type = media[:type]
      file = bucket.files.create({
        key: "s/#{filename}",
        public: true,
        body: open(media[:tempfile]),
        content_type: content_type,
        metadata: { "Cache-Control" => "public, max-age=315360000"}
      })

      if ENV["NO_CNAME"]
        return "<mediaurl>#{file.public_url}</mediaurl>"
      else
        return "<mediaurl>http://#{ENV["S3_BUCKET"]}/#{file.key}</mediaurl>"
      end

    rescue => e
      puts "Error uploading file #{media[:name]} to S3: #{e.message}"
      if e.message =~ /Broken pipe/ && retries < 5
        retries += 1
        retry
      end

      500
    end
  end

  def bucket
    # Bad idea.
    # unless ENV["AWS_ACCESS_KEY_ID"] and ENV["AWS_SECRET_ACCESS_KEY"]
    #   kcdata = `security find-internet-password 2>&1 -gs s3.amazonaws.com`
    #   ENV["AWS_ACCESS_KEY_ID"] = kcdata[/"acct"<blob>="(.*)"/, 1]
    #   ENV["AWS_SECRET_ACCESS_KEY"] = kcdata[/password: "(.*)"/, 1]
    # end

    s3 = Fog::Storage.new({
      provider: "AWS",
      aws_access_key_id: ENV["AWS_ACCESS_KEY_ID"],
      aws_secret_access_key: ENV["AWS_SECRET_ACCESS_KEY"],
      region: ENV["AWS_REGION"]
    })
    s3.directories.get(ENV["S3_BUCKET"])
  end

  def generate_key(i)
    s = ""

    # LOL
    i = (i.to_s(base=9).to_i + 1).to_s.reverse.to_i

    while i > 0
      puts "#{i}: #{s}"
      s << SIXTYTWO[(i.modulo(62))]
      i /= 62
    end
    puts "#{s}"
    s.reverse
  end
end
