module IconDefinitions
  # カテゴリ用アイコン定義
  # key: Material Symbols の識別名（DBに保存される値）
  # value: label（アイコンの意味ラベル）
  # 既存アイコン名を削除すると既存DBデータが孤立するため、削除禁止。
  CATEGORY_ICONS = {
    "local_cafe"          => { label: "飲みもの" },
    "accessibility_new"   => { label: "体調" },
    "sentiment_satisfied" => { label: "気持ち" },
    "volunteer_activism"  => { label: "お願い" },
    "home"                => { label: "生活・家" },
    "restaurant"          => { label: "食事" },
    "medical_services"    => { label: "医療" },
    "directions_walk"     => { label: "外出" },
    "music_note"          => { label: "趣味・音楽" },
    "park"                => { label: "散歩" },
    "bed"                 => { label: "睡眠" },
    "bathtub"             => { label: "入浴" },
    "phone_in_talk"       => { label: "連絡" },
    "star"                => { label: "お気に入り" },
    "exercise"            => { label: "運動" },
    "conversation"        => { label: "会話" }
  }.freeze

  # FlowItem グループ定義
  # key: グループの識別子（:drink 等）
  # value: 表示ラベル（日本語）
  FLOW_ITEM_ICON_GROUPS = {
    drink:   "飲みもの",
    food:    "食べもの",
    emotion: "気持ち",
    person:  "人・家族",
    daily:   "日常",
    medical: "医療・体調"
  }.freeze

  # FlowItem 用アイコン定義
  # key: Material Symbols の識別名（DBに保存される値）
  # value: group（FLOW_ITEM_ICON_GROUPS のキー）
  # 既存アイコン名を削除すると既存DBデータが孤立するため、削除禁止。
  FLOW_ITEM_ICONS = {
    # 飲みもの
    "water_drop"                       => { group: :drink },
    "local_drink"                      => { group: :drink },
    "emoji_food_beverage"              => { group: :drink },
    "coffee"                           => { group: :drink },
    "local_cafe"                       => { group: :drink },
    "water"                            => { group: :drink },
    "grocery"                          => { group: :drink },
    "sports_bar"                       => { group: :drink },
    "liquor"                           => { group: :drink },

    # たべもの
    "washoku"                          => { group: :food },
    "rice_bowl"                        => { group: :food },
    "stockpot"                         => { group: :food },
    "set_meal"                         => { group: :food },
    "nutrition"                        => { group: :food },
    "bakery_dining"                    => { group: :food },
    "cake"                             => { group: :food },
    "icecream"                         => { group: :food },

    # 気持ち
    "sentiment_very_satisfied"         => { group: :emotion },
    "sentiment_excited"                => { group: :emotion },
    "sentiment_satisfied"              => { group: :emotion },
    "sentiment_content"                => { group: :emotion },
    "sentiment_neutral"                => { group: :emotion },
    "sentiment_worried"                => { group: :emotion },
    "sentiment_dissatisfied"           => { group: :emotion },
    "sentiment_sad"                    => { group: :emotion },
    "sentiment_frustrated"             => { group: :emotion },
    "sentiment_very_dissatisfied"      => { group: :emotion },
    "sentiment_extremely_dissatisfied" => { group: :emotion },
    "mood_heart"                       => { group: :emotion },
    "thumb_up"                         => { group: :emotion },
    "sick"                             => { group: :emotion },
    "sentiment_stressed"               => { group: :emotion },

    # 人・家族
    "elderly"                          => { group: :person },
    "elderly_woman"                    => { group: :person },
    "person"                           => { group: :person },
    "man"                              => { group: :person },
    "woman"                            => { group: :person },
    "face"                             => { group: :person },
    "face_3"                           => { group: :person },
    "face_4"                           => { group: :person },
    "face_6"                           => { group: :person },
    "face_2"                           => { group: :person },
    "child_care"                       => { group: :person },
    "pets"                             => { group: :person },

    # 日常
    "bed"                              => { group: :daily },
    "bathtub"                          => { group: :daily },
    "shower"                           => { group: :daily },
    "directions_walk"                  => { group: :daily },
    "music_note"                       => { group: :daily },
    "tv"                               => { group: :daily },
    "book"                             => { group: :daily },
    "phone_in_talk"                    => { group: :daily },
    "park"                             => { group: :daily },
    "chair"                            => { group: :daily },
    "wc"                               => { group: :daily },
    "lightbulb"                        => { group: :daily },
    "ac_unit"                          => { group: :daily },
    "wb_sunny"                         => { group: :daily },

    # 医療・体調
    "medication"                       => { group: :medical },
    "thermometer"                      => { group: :medical },
    "stethoscope"                      => { group: :medical },
    "healing"                          => { group: :medical },
    "local_hospital"                   => { group: :medical },
    "wheelchair_pickup"                => { group: :medical },
    "blood_pressure"                   => { group: :medical },
    "ambulance"                        => { group: :medical },
    "medical_mask"                     => { group: :medical },
    "vital_signs"                      => { group: :medical },
    "syringe"                          => { group: :medical },
    "thermostat"                       => { group: :medical }
  }.freeze

  # カラー定義
  # key: DBに保存する semantic key（"orange" 等）
  # text: アイコン表示用 Tailwind テキストカラークラス
  # bg:   カラーピッカースウォッチ用 Tailwind 背景カラークラス
  # DBには semantic key を保存し、表示時に icon_color_class() / icon_bg_class() で変換する。
  ICON_COLORS = {
    "red"     => { text: "text-red-500", bg: "bg-red-500"  },
    "orange"  => { text: "text-orange-500", bg: "bg-orange-500"  },
    "amber"   => { text: "text-amber-500",  bg: "bg-amber-500"   },
    "yellow"  => { text: "text-yellow-500",  bg: "bg-yellow-500"   },
    "lime"    => { text: "text-lime-500",   bg: "bg-lime-500"    },
    "green"    => { text: "text-green-500",   bg: "bg-green-500"    },
    "emerald" => { text: "text-emerald-500", bg: "bg-emerald-500" },
    "cyan"    => { text: "text-cyan-500",   bg: "bg-cyan-500"    },
    "sky"     => { text: "text-sky-500",    bg: "bg-sky-500"     },
    "blue"     => { text: "text-blue-500",    bg: "bg-blue-500"     },
    "indigo"  => { text: "text-indigo-500", bg: "bg-indigo-500"  },
    "violet"  => { text: "text-violet-500", bg: "bg-violet-500"  },
    "pink"    => { text: "text-pink-400",   bg: "bg-pink-400"    },
    "rose"    => { text: "text-rose-400",   bg: "bg-rose-400"    },
    "gray"    => { text: "text-gray-400",   bg: "bg-gray-400"    }
  }.freeze
end
