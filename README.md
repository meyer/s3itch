# Tweetbot Custom Media Uploader

Upload photos and videos to your own S3 bucket, straight from Tweetbot.

## Setup
1. **Provision a new Heroku app:**
  ```bash
  git clone https://github.com/meyer/tweetbot-custom-media-s3.git
  cd tweetbot-custom-media-s3
  heroku create --stack cedar
  git push heroku master
  ```

2. **Set environmental variables**
  ```bash
  # https://portal.aws.amazon.com/gp/aws/securityCredentials
  heroku config:set AWS_ACCESS_KEY_ID=XXXXXXXXXXXXX`
  heroku config:set AWS_SECRET_ACCESS_KEY=XXXXXXXXXXXXXXXXXXXXXXXXX

  heroku config:set AWS_REGION=your-region-1 # mine was "us-west-2"
  heroku config:set S3_BUCKET=example.com

  heroku config:set HTTP_USER=username
  heroku config:set HTTP_PASS=password
  ```

3. **Configure Tweetbot**

  Tweetbot for OSX and iOS supports a custom endpoint for sharing photos and videos on Twitter. This is what it looks like:

  `http://username:password@your-heroku-url.herokuapp.com/tweetbot/`

  Here's a screenshot of the configuration screen in Tweetbot:

  ![Tweetbot Configuration](https://s3itch.s3.amazonaws.com/tweetbot%2F1tqjKx.jpg)
