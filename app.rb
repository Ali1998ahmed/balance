require 'sinatra'
require 'twilio-ruby'
require File.expand_path('../lib/transcription', __FILE__)
require File.expand_path('../lib/debit_card_number', __FILE__)

class EbtBalanceSmsApp < Sinatra::Base
  TWILIO_SERVICE = TwilioService.new(Twilio::REST::Client.new(ENV['TWILIO_SID'], ENV['TWILIO_AUTH']))

  post '/' do
    @texter_phone_number = params["From"]
    @debit_number = DebitCardNumber.new(params["Body"])
    @twiml_url = "#{request.env['rack.url_scheme']}://#{request.env['HTTP_HOST']}/get_balance?phone_number=#{@texter_phone_number}"
    if @debit_number.is_valid?
      call = TWILIO_SERVICE.make_call( \
        url: @twiml_url, \
        to: "+18773289677", \
        send_digits: "ww1ww#{@debit_number.to_s}", \
        from: ENV['TWILIO_NUMBER'], \
        record: "true", \
        method: "GET" \
      )
      text_message = TWILIO_CLIENT.account.messages.create( \
        to: @texter_phone_number, \
        from: ENV['TWILIO_NUMBER'], \
        body: "Thanks! Please wait 1-2 minutes while we check your EBT balance." \
      )
    else
      text_message = TWILIO_CLIENT.account.messages.create( \
        to: @texter_phone_number, \
        from: ENV['TWILIO_NUMBER'], \
        body: "Sorry, that EBT number doesn't look right. Please try again." \
      )
    end
  end

  get '/get_balance' do
    @phone_number = params[:phone_number].strip
    @my_response = Twilio::TwiML::Response.new do |r|
      r.Record :transcribeCallback => "#{request.env['rack.url_scheme']}://#{request.env['HTTP_HOST']}/#{@phone_number}/send_balance", :maxLength => 18 #:transcribe => true
    end
    @my_response.text
  end

  post '/:phone_number/send_balance' do
    transcription = Transcription.new(params["TranscriptionText"])
    TWILIO_SERVICE.send_text( \
      to: params[:phone_number].strip, \
      from: ENV['TWILIO_NUMBER'], \
      body: "Hi! Your food stamp balance is #{transcription.ebt_amount} and your cash balance is #{transcription.cash_amount}." \
    )
  end
end

class TwilioService
  attr_reader :client

  def initialize(twilio_client)
    @client = twilio_client
  end

  def make_call(params)
    @client.account.calls.create(params)
  end

  def send_text(params)
    @client.account.messages.create(params)
  end
end
