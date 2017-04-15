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
        response.reply(current_kintai)
      end

      def send_kintai(user: user, room: room)
        target = Source.new(user: user, room: room)
        robot.send_message(target, current_kintai)
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

      def reaction_added(_payload)
        p _payload
      end

      def code(response)
        code = response.matches[0][0]
        Gmail.credentials_from_code

        response.reply("Confirmed")
      end

      def current_kintai
        if Gmail.authorize.nil?
          auth_url = Gmail.authorization_url
          return <<-EOS
Authenticate your Google account.
Then tell me the code as follows: `code \#{your_code}`

#{auth_url}
          EOS
        end

        kintai_info
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

          reason = "私用のため、"
          if text.match(/電車|列車/)
            reason = "電車遅延のため、"
          end
          if text.match(/体調|痛/)
            reason = "体調不良のため、"
          end
          if text.match(/健康診断|検診|健診/)
            reason = "健康診断のため、"
          end

          at = "出社時刻未定です。"
          if hm = text.match(/([0-1][0-9]|[2][0-3]):[0-5][0-9]/)
            at = "#{hm}頃出社予定です。"
          elsif min = text.match(/([0-5][0-9])分/)
            at = "10:#{min[1]}頃出社予定です。"
          end

          if text.match(/おやすみ|休み|有給|休暇/)
            reason = "本日お休みです。"
            at = ""
          end

          texts << "#{name}さん: #{reason}#{at}\n"
        end

        texts << config.template_footer
      end

      Lita.register_handler(self)
    end
  end
end
