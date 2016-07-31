require "spec_helper"

describe Lita::Handlers::Kintai, lita_handler: true do
  it { is_expected.to route('kintai') }
  it { is_expected.to route('kintai').to(:kintai) }

  it '#kintai' do
    send_message('kintai')
    expect(replies.last).not_to eq("")
  end
end
