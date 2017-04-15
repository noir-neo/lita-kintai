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

      it 'returns kintai list' do
        send_command('kintai')
        expect(replies.last).not_to be_nil
      end
    end
  end
end
