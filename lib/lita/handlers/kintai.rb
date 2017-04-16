require 'date'
require 'rufus-scheduler'
require 'mail'

module Lita
  module Handlers
    class Kintai < Handler
      config :query, type: String
      config :mail_to, type: String, default: ''
      config :mail_cc, type: String, default: ''
      config :template_subject, type: String, default: ''
      config :template_header, type: String, default: ''
      config :template_footer, type: String, default: ''
      config :template_info, type: String, default: ''
      config :schedule_cron, type: String, default: nil
      config :schedule_room, type: String, default: nil

      route /kintai/i, :kintai, command: true
      route /^draft\s+(.+)/im, :draft, command: true
      route /^code\s+(.+)/, :code, command: true

      on :loaded, :load_on_start
      on :slack_reaction_added, :reaction_added

      def kintai(response)
        if Gmail.authorized?
          register_draft(response, kintai_info)
        else
          response.reply(authenticate_info)
        end
      end

      def draft(response)
        info = response.matches[0][0]
        register_draft(response, info)
      end

      def register_draft(response, info)
        mail = create_kintai_mail(info)
        reply = response.reply(mail_to_message(mail))
        @@draft = { channel: reply["channel"], ts: reply["ts"], mail: mail }
        reply
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
        send_message(user: user, room: room, message: kintai_or_authenticate)
      end

      def reaction_added(_payload)
        case _payload[:name]
        when '+1' then
          if !@@draft.nil? &&
            _payload[:item]["type"] == "message" &&
            _payload[:item]["channel"] == @@draft[:channel] &&
            _payload[:item]["ts"] == @@draft[:ts]
            if Gmail.authorized?
              # TODO: 成功失敗
              send_mail(@@draft[:mail])
              @@draft = nil
              send_message(room: _payload[:item]["channel"],
                message: 'Sent email.')
            else
              send_message(room: _payload[:item]["channel"],
                message: authenticate_info)
            end
          end
        end
      end

      def send_message(user: user, room: room, message: message)
        target = Source.new(user: user, room: room)
        robot.send_message(target, message)
      end

      def create_kintai_mail(info)
        create_mail(
          to: config.mail_to,
          cc: config.mail_cc,
          subject: kintai_subject,
          body: kintai_body(info)
        )
      end

      def mail_to_message(mail)
        <<-EOS
To: #{mail.to}
Cc: #{mail.cc}
Subject: #{mail.subject}
#{mail.body.to_s}
        EOS
      end

      def create_mail(to: to, cc: cc, subject: subject, body: body)
        Mail.new do
          to to
          cc cc
          subject subject
          body body
        end
      end

      def send_mail(mail)
        return Gmail.send_message(mail)
      end

      def kintai_info
        texts = ""

        mails = Gmail.find_mail(config.query)
        # query の `newer:#{Date.today.strftime("%Y/%m/%d")}` 昨日のも一部返ってくる
        # `newer_than:1d` だと24h以内になるので、ここで今日のだけにする
        mails.select{ |m| m[:date] > Date.today.to_time }.each do |m|
          name = m[:from].split("\"")[1]

          text = m[:subject] + m[:body]
          info = kintai_from_text(text)

          texts << "#{name}さん: #{info}\n"
        end
        texts << config.template_info
      end

      def self.kintai_from_text(text)
        reason = kintai_reason(text)
        time = kintai_time(text)
        "#{reason}のため、#{time}です。"
      end

      def kintai_subject
        "#{Date.today.strftime("%m/%d")} (#{%w(日 月 火 水 木 金 土)[Date.today.wday]})#{config.template_subject}"
      end

      def kintai_body(info)
        <<-EOS
#{config.template_header}

#{info}

#{config.template_footer}
        EOS
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
        elsif min = text.match(/(([0-5])*[0-9])分/)
          return "10:#{min[1].rjust(2, "0")}頃出社予定"
        elsif half = text.match(/([0-1][0-9]|[2][0-3])時半/)
          return "#{half[1]}:30頃出社予定"
        elsif half = text.match(/(\d)時間半/)
          return "#{10+half[1].to_i}:30頃出社予定"
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
