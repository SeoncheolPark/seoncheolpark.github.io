#set page(
  fill: white
)

#show heading: it => block(width: 100%)[
  #set text(weight: "extrabold", font: ("Pretendard", "Helvetica", "IBM Plex Sans", "IBM Plex Sans KR"))
  #(it.body)
]


#align(center)[
    #text("Seoncheol Park", font: ("Pretendard", "Helvetica", "IBM Plex Sans", "IBM Plex Sans KR"), weight:"black", size:30pt)
  ]

#set text(font: ("IBM Plex Sans", "IBM Plex Sans KR"))
