require 'date'
require 'rufus-scheduler'

module Lita
  module Handlers
    class Kintai < Handler
      config :query, type: String
      config :template_header, type: String, default: ''
      config :template_footer, type: String, default: ''
      config :schedule_cron, type: String, default: nil
      config :schedule_room, type: String, default: nil

      route /kintai/i, :kintai, command: true
      route /^code\s+(.+)/, :code, command: true

      on :loaded, :load_on_start
      on :slack_reaction_added, :reaction_added

      def kintai(response)
        response.reply(kintai_or_authenticate)
      end

      def code(response)
        code = response.matches[0][0]
        Gmail.credentials_from_code(code)

        response.reply("Confirmed")
      end

      def load_on_start(_payload)
        schedule
      end

      def schedule
        return if config.schedule_cron.nil?
        return if config.schedule_room.nil?
        scheduler = Rufus::Scheduler.new
        scheduler.cron config.schedule_cron do
          send_kintai(room: config.schedule_room)
        end
      end

      def send_kintai(user: user, room: room)
        target = Source.new(user: user, room: room)
        robot.send_message(target, kintai_or_authenticate)
      end

      def reaction_added(_payload)
        p _payload
      end

      def kintai_or_authenticate
        if Gmail.authorized?
          return kintai_info
        end
        authenticate_info
      end

      def kintai_info
        texts = ""
        texts << "#{Date.today.strftime("%m/%d")} (#{%w(日 月 火 水 木 金 土)[Date.today.wday]})#{config.template_header}"

        mails = Gmail.find_mail(config.query)
        # query の `newer:#{Date.today.strftime("%Y/%m/%d")}` 昨日のも一部返ってくる
        # `newer_than:1d` だと24h以内になるので、ここで今日のだけにする
        mails.select{ |m| m[:date] > Date.today.to_time }.each do |m|
          name = m[:from].split("\"")[1]

          text = m[:subject] + m[:body]
          info = kintai_from_text(text)

          texts << "#{name}さん: #{info}\n"
        end
        texts << config.template_footer
      end

      def self.kintai_from_text(text)
        reason = kintai_reason(text)
        time = kintai_time(text)
        "#{reason}のため、#{time}です。"
      end

      def self.kintai_reason(text)
        if text.match(/電車|列車/)
          return "電車遅延"
        elsif text.match(/体調|痛/)
          return "体調不良"
        elsif text.match(/健康診断|検診|健診/)
          return "健康診断"
        end
        return  "私用"
      end

      def self.kintai_time(text)
        if hm = text.match(/([0-1][0-9]|[2][0-3]):[0-5][0-9]/)
          return "#{hm}頃出社予定"
        elsif min = text.match(/([0-5][0-9])分/)
          return "10:#{min[1]}頃出社予定"
        elsif text.match(/おやすみ|休み|有給|休暇/)
          return "本日お休み"
        end
        return "出社時刻未定"
      end

      def authenticate_info
        <<-EOS
Authenticate your Google account.
Then tell me the code as follows: `code \#{your_code}`

#{Gmail.authorization_url}
        EOS
      end

      Lita.register_handler(self)
    end
  end
end
