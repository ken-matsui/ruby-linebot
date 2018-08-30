require 'sinatra'
require 'line/bot'
require 'rest-client'
require "cgi"


#get '/' do
#    "Hello world"
#end

def client
    @client ||= Line::Bot::Client.new { |config|
        config.channel_secret = ENV["LINE_CHANNEL_SECRET"]
        config.channel_token = ENV["LINE_CHANNEL_TOKEN"]
    }
end

post '/callback' do
    body = request.body.read
    
    signature = request.env['HTTP_X_LINE_SIGNATURE']
    unless client.validate_signature(body, signature)
        error 400 do 'Bad Request' end
    end
    
    events = client.parse_events_from(body)
    events.each { |event|
        case event
            when Line::Bot::Event::Message
            case event.type
                when Line::Bot::Event::MessageType::Text
                return_msg = event.message['text']
                
                # 宣言のみ
                message = {}
                sticker = {}
                
                if return_msg =~ /[0-9]{4}/
                    # 4桁の数字抽出．干支スタンプの出力
                    year = return_msg.match(/[0-9]{4}/)[0].to_i
                    
                    sticker = {
                        type: 'sticker',
                        packageId: "4",
                        stickerId: 621 + ((year - 4) % 12)
                    }
                    message = {
                        type: 'text',
                        text: "#{year}年生まれなんだね！"
                    }
                    client.reply_message(event['replyToken'], [sticker, message])
                    
                elsif return_msg =~ /くじ/ || return_msg =~ /クジ/
                    kuji = ['大吉', '中吉', '凶']
                    num = rand(3)
                    return_msg = kuji[num]

                    emoji = {}
                    case num
                        when 0
                        emoji = "\u{1F601}"
                        when 1
                        emoji = "\u{1F609}"
                        when 2
                        emoji = "\u{1F631}"
                    end
                    
                    message = {
                        type: 'text',
                        text: return_msg + emoji
                    }
                    client.reply_message(event['replyToken'], message)
                    
                elsif return_msg =~ /ヘルプ/ || return_msg =~ /help/ || return_msg =~ /へるぷ/
                    message = {
                        type: 'text',
                        text: "くじっていうと，くじが引けるよ！\n(例：おみくじ引いて=>大吉\u{1F601})\n生まれ年を言うと，干支をスタンプで返すよ！！\n(例：1998年生まれです！=>虎のスタンプ)\nおしゃべりもできるよ！！！！"
                    }
                    client.reply_message(event['replyToken'], message)

                elsif return_msg =~ /まつけん/
                    message = {
                        type: 'text',
                        text: "わたしまつけんです"
                    }
                    client.reply_message(event['replyToken'], message)
                    
                else
					request_content = {'key' => '', 'message' => CGI.escape(return_msg)}
                    request_params = request_content.reduce([]) do |params, (key, value)|
                        params << "#{key.to_s}=#{value}"
                    end
                    rest = RestClient.get('https://chatbot-api.userlocal.jp/api/chat?' + request_params.join('&').to_s)
                    result = JSON.parse(rest)
                    
                    # 絵文字の追加 適当に選択
                    tekito = rand(1537..1615)
                    #emocode = "1F" + tekito.to_s(16)
                    tekitochar = "1F" + tekito.to_s
                    emocode = sprintf("%#x", tekitochar.to_i)
                    
                    kaesu = result['result'].to_s
                    #kaesu += emocode.pack("H*").to_s
                    
                    message = {
                        type: 'text',
                        text: kaesu
                    }
                    client.reply_message(event['replyToken'], message)
                    
                end
                
				when Line::Bot::Event::MessageType::Image, Line::Bot::Event::MessageType::Video
                
                message = {
                    type: 'text',
                    text: "見たよ！いいね！"
                }
                client.reply_message(event['replyToken'], message)
                
                when Line::Bot::Event::MessageType::Sticker
                
                message = {
                    type: 'text',
                    text: "スタンプかあ...."
                }
                client.reply_message(event['replyToken'], message)
                
                when Line::Bot::Event::MessageType::Audio
                
                message = {
                    type: 'text',
                    text: "音声うるさ"
                }
                client.reply_message(event['replyToken'], message)
                
                response = client.get_message_content(event.message['id'])
                tf = Tempfile.open("content")
                tf.write(response.body)
            end
        end
    }
    
    "OK"
end
