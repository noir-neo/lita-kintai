require "spec_helper"

describe Lita::Handlers::Kintai, lita_handler: true do
  it { is_expected.to route_command('kintai') }
  it { is_expected.to route_command('kintai').to(:kintai) }
  it { is_expected.to route_command('code 012abc') }
  it { is_expected.to route_command('code 012abc').to(:code) }

  describe '#kintai' do
    context 'when authenticated' do
      before do
        allow(Gmail).to receive(:authorized?).and_return(true)
        allow(Gmail).to receive(:find_mail).and_return(
          [
            {
              subject: '',
              from: '',
              date: Date.today.to_time,
              body: '',
            }
          ]
        )
      end

      xit 'returns kintai list' do
        send_command('kintai')
        expect(replies.last).not_to be_nil
      end
    end
  end

  describe '.kintai_from_text' do
    subject { Lita::Handlers::Kintai.kintai_from_text(text) }

    context '理由と時間がマッチする時' do
      let(:text) { "電車が遅れていて5分ほど遅れます" }
      it { is_expected.to eq "電車遅延のため、10:05頃出社予定です。" }
    end

    context '理由がマッチする時' do
      let(:text) { "電車が遅れていて出社時刻わかりません" }
      it { is_expected.to eq "電車遅延のため、出社時刻未定です。" }
    end

    context '時間がマッチする時' do
      let(:text) { "5分ほど遅れます" }
      it { is_expected.to eq "私用のため、10:05頃出社予定です。" }
    end

    context '理由と時間どちらもマッチしない時' do
      let(:text) { "大変なことになったのでめっちゃ遅れます" }
      it { is_expected.to eq "私用のため、出社時刻未定です。" }
    end
  end

  describe '.kintai_reason(text)' do
    subject { Lita::Handlers::Kintai.kintai_reason(text) }

    context '「電車」が含まれる時' do
      let(:text) { "電車遅延のため" }
      it { is_expected.to eq "電車遅延" }
    end

    context '「体調不良」が含まれる時' do
      let(:text) { "体調不良のため" }
      it { is_expected.to eq "体調不良" }
    end

    context '「健康診断」が含まれる時' do
      let(:text) { "健康診断に行くので" }
      it { is_expected.to eq "健康診断" }
    end

    context 'いずれにもマッチしない時' do
      let(:text) { "寝坊したので" }
      it { is_expected.to eq "私用" }
    end
  end

  describe '.kintai_time(text)' do
    subject { Lita::Handlers::Kintai.kintai_time(text) }

    context '「HH:mm」が含まれる時' do
      let(:text) { "12:00頃出社します" }
      it { is_expected.to eq "12:00頃出社予定" }
    end

    context '「mm分」が含まれる時' do
      let(:text) { "10分ほど遅れます" }
      it { is_expected.to eq "10:10頃出社予定" }
    end

    context '「m分」が含まれる時' do
      let(:text) { "5分ほど遅れます" }
      it { is_expected.to eq "10:05頃出社予定" }
    end

    context '「HH時半」が含まれる時' do
      let(:text) { "10時半ごろに出社します" }
      it { is_expected.to eq "10:30頃出社予定" }
    end

    context '「n時間半」が含まれる時' do
      let(:text) { "1時間半ほど遅れます" }
      it { is_expected.to eq "11:30頃出社予定" }
    end

    context '「休み」が含まれる時' do
      let(:text) { "お休みをいただいてます" }
      it { is_expected.to eq "本日お休み" }
    end

    context 'いずれにもマッチしない時' do
      let(:text) { "出社時刻わかり次第また連絡します" }
      it { is_expected.to eq "出社時刻未定" }
    end
  end
end
