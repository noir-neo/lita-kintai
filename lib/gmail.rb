require 'google/apis/gmail_v1'
require 'googleauth'
require 'googleauth/stores/file_token_store'

require 'fileutils'

class Gmail
  OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'
  APPLICATION_NAME = 'Lita Kintai'
  CLIENT_SECRETS_PATH = 'client_secret.json'
  CREDENTIALS_PATH = File.join(Dir.home, '.credentials',
                               "lita-kintai.yaml")
  SCOPE = Google::Apis::GmailV1::AUTH_GMAIL_READONLY
  USER_ID = 'default'

  def self.authorize
    return @service if !@service.nil? && !@service.authorization.nil?

    credentials = authorizer.get_credentials(USER_ID)
    if credentials
      @service.authorization = credentials
      return @service
    end

    return nil
  end

  def self.authorizer
    return @authorizer unless @authorizer.nil?

    @service = Google::Apis::GmailV1::GmailService.new
    @service.client_options.application_name = APPLICATION_NAME

    FileUtils.mkdir_p(File.dirname(CREDENTIALS_PATH))

    client_id = Google::Auth::ClientId.from_file(CLIENT_SECRETS_PATH)
    token_store = Google::Auth::Stores::FileTokenStore.new(
      file: CREDENTIALS_PATH)
    @authorizer = Google::Auth::UserAuthorizer.new(
      client_id, SCOPE, token_store)
  end

  def self.credentials_from_code
    authorizer.get_and_store_credentials_from_code(
    user_id: USER_ID, code: code, base_url: OOB_URI)
  end

  def self.authorization_url
    authorizer.get_authorization_url(base_url: OOB_URI)
  end

  def self.find_mail(query)
    ids = @service.list_user_messages('me', q: query)

    return [] unless ids.messages
    ids.messages.map do |message|
      find_mail_by_id(message.id)
    end
  end

  def self.find_mail_by_id(id)
    results = @service.get_user_message('me', id)

    body = results.payload.parts ?
      results.payload.parts.first.body.data :
      results.payload.body.data
    headers = results.payload.headers

    {
      subject: headers.select { |e| e.name == 'Subject'}.first.value,
      from: headers.select { |e| e.name == 'From'}.first.value,
      date: Time.parse(headers.select { |e| e.name == 'Date'}.first.value),
      body: body.force_encoding('utf-8'),
    }
  end
end
