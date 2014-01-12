require "bundler"
Bundler.setup

require "sinatra"
require "fog"
require "mime/types"
require "uri"
require "rmagick"
include Magick

# TODO: Player card support. Maybe. Video is annoying.
TWITTER_PHOTO_CARDS_ENABLED = false
TWITTER_PLAYER_CARDS_ENABLED = false

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

  post "/tweetbot/*" do
    media = params["media"]

    # Increment counter
    counter_filename = "s/_counter.txt"
    begin
      counter = bucket.files.get(counter_filename).body.to_i + 1
    rescue
      counter = 1
    end

    counter_file = bucket.files.create(
      :key => counter_filename,
      :body   => counter.to_s,
      :public => false, # none of your business
      :content_type => "text/plain"
    )

    # TODO: Tweak this.
    counter += 18000

    # Generate
    upload_key = "s/#{generate_key(counter)}"
    ext = File.extname(media[:filename])

    # puts upload_key+"!!!"
    # throw :halt, response

    retries = 0
    begin
      content_type = media[:type]

      # Save source image
      source_img_s3 = bucket.files.create(
        key: "#{upload_key}#{ext}",
        public: true,
        body: open(media[:tempfile]),
        content_type: content_type,
        metadata: { "Cache-Control" => "public, max-age=315360000"}
      )

      # Conditionally generate
      media_card_s3 = nil

      if TWITTER_PHOTO_CARDS_ENABLED

        case ext
        when ".png", ".jpg"
          preview_img_s3 = source_img_s3

          # Resize image if it needs it.
          preview_img = Image.read(media[:tempfile].path).first.change_geometry ('750x560>') do |cols, rows, img|
            img.resize_to_fit!(cols, rows)
            preview_img_s3 = bucket.files.create(
              key: "#{upload_key}/preview#{ext}",
              public: true,
              body: img.to_blob,
              content_type: content_type,
              metadata: { "Cache-Control" => "public, max-age=315360000"}
            )
            img
          end

          media_card_data = {
            width: preview_img.columns,
            height: preview_img.rows,
            preview_img: "http://#{ENV["S3_BUCKET"]}/#{preview_img_s3.key}",
            source_img:  "http://#{ENV["S3_BUCKET"]}/#{source_img_s3.key}",
            source_img_name: "#{upload_key}#{ext}"
          }

          media_card_s3 = bucket.files.create(
            key: "#{upload_key}/index.html",
            public: true,
            body: erb(:media, :locals => media_card_data),
            content_type: "text/html",
            metadata: { "Cache-Control" => "public, max-age=315360000"}
          )
        end
      end

      return "<mediaurl>http://#{ENV["S3_BUCKET"]}/#{upload_key}#{(media_card_s3 ? "/" : ext)}</mediaurl>"

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
    s3 = Fog::Storage.new({
      provider: "AWS",
      aws_access_key_id: ENV["AWS_ACCESS_KEY_ID"],
      aws_secret_access_key: ENV["AWS_SECRET_ACCESS_KEY"],
      region: ENV["AWS_REGION"]
    })
    s3.directories.get(ENV["S3_BUCKET"])
  end

  def generate_key(i)
    puts "Old counter: #{i}"
    s = ""
    i = (i.to_s(base=9).to_i + 1).to_s.reverse.to_i # LOL
    puts "New counter: #{i}"

    while i > 0
      s << SIXTYTWO[(i.modulo(62))]
      i /= 62
    end
    s.reverse
  end
end
