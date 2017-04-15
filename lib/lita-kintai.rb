require "lita"

Lita.load_locales Dir[File.expand_path(
  File.join("..", "..", "locales", "*.yml"), __FILE__
)]

require "gmail"
require "lita/handlers/kintai"

Lita::Handlers::Kintai.template_root File.expand_path(
  File.join("..", "..", "templates"),
 __FILE__
)
