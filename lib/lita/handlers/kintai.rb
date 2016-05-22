require 'google/apis/gmail_v1'
require 'googleauth'
require 'googleauth/stores/file_token_store'

require 'fileutils'

module Lita
  module Handlers
    class Kintai < Handler
      config :query, type: String
      config :template_header, type: String
      config :template_footer, type: String

      route(/kintai/i, :kintai)
      route(/^code\s+(.+)/, :code)

      OOB_URI = 'urn:ietf:wg:oauth:2.0:oob'
      APPLICATION_NAME = 'Lita Kintai'
      CLIENT_SECRETS_PATH = 'client_secret.json'
      CREDENTIALS_PATH = File.join(Dir.home, '.credentials',
                                   "lita-kintai.yaml")
      SCOPE = Google::Apis::GmailV1::AUTH_GMAIL_READONLY
      USER_ID = 'default'

      def kintai(response)
        response.reply(current_kintai)
      end

      def code(response)
        code = response.matches[0][0]
        authorizer.get_and_store_credentials_from_code(
          user_id: USER_ID, code: code, base_url: OOB_URI)

        response.reply("Authentication has been completed.")
      end

      def current_kintai
        if authorize.nil?
          auth_url = authorizer.get_authorization_url(base_url: OOB_URI)
          return <<-EOS
Authenticate your Google account.
Then tell me the code as follows: `code \#{your_code}`

#{auth_url}
          EOS
        end

        texts = config.template_header

        mails = find_mail(config.query)
        # FIXME: query の 'newer:#{Date.today.strftime("%Y/%m/%d")}'
        # 昨日のも一部返ってくる(？)し、ここで今日のだけにするしかない?
        # 'newer_than:1d' だと24h以内になるし…
        mails.each do |m|
          texts << <<-EOS
---
#{m[:date]}
#{m[:subject]}
#{m[:body]}
          EOS
        end

        texts << config.template_footer
      end

      def authorize
        return @service if !@servise.nil? && !@servise.authorization.nil?

        credentials = authorizer.get_credentials(USER_ID)
        if credentials
          @service.authorization = credentials
          return @service
        end

        return nil
      end

      def authorizer
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

      def find_mail(query)
        ids = @service.list_user_messages('me', q: query)

        return [] unless ids.messages
        ids.messages.map do |message|
          find_mail_by_id(message.id)
        end
      end

      def find_mail_by_id(id)
        results = @service.get_user_message('me', id)

        body = results.payload.parts ?
          results.payload.parts.first.body.data :
          results.payload.body.data
        headers = results.payload.headers

        {
          subject: headers.select { |e| e.name == 'Subject'}.first.value,
          # TODO: アドレスだけ抜いて名前は返したい
          # from: headers.select { |e| e[:name] == 'From'}.first.value,
          date: Time.parse(headers.select { |e| e.name == 'Date'}.first.value),
          body: body.force_encoding('utf-8'),
        }
      end

      Lita.register_handler(self)
    end
  end
end