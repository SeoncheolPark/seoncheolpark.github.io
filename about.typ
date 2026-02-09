// Simple numbering for non-book documents
#let equation-numbering = "(1)"
#let callout-numbering = "1"
#let subfloat-numbering(n-super, subfloat-idx) = {
  numbering("1a", n-super, subfloat-idx)
}

// Theorem configuration for theorion
// Simple numbering for non-book documents (no heading inheritance)
#let theorem-inherited-levels = 0

// Theorem numbering format (can be overridden by extensions for appendix support)
// This function returns the numbering pattern to use
#let theorem-numbering(loc) = "1.1"

// Default theorem render function
#let theorem-render(prefix: none, title: "", full-title: auto, body) = {
  if full-title != "" and full-title != auto and full-title != none {
    strong[#full-title.]
    h(0.5em)
  }
  body
}
// Some definitions presupposed by pandoc's typst output.
#let content-to-string(content) = {
  if content.has("text") {
    content.text
  } else if content.has("children") {
    content.children.map(content-to-string).join("")
  } else if content.has("body") {
    content-to-string(content.body)
  } else if content == [ ] {
    " "
  }
}

#let horizontalrule = line(start: (25%,0%), end: (75%,0%))

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

// Use nested show rule to preserve list structure for PDF/UA-1 accessibility
// See: https://github.com/quarto-dev/quarto-cli/pull/13249#discussion_r2678934509
#show terms: it => {
  show terms.item: item => {
    set text(weight: "bold")
    item.term
    block(inset: (left: 1.5em, top: -0.4em))[#item.description]
  }
  it
}

// Prevent breaking inside definition items, i.e., keep term and description together.
#show terms.item: set block(breakable: false)

// Some quarto-specific definitions.

#show raw.where(block: true): set block(
    fill: luma(230),
    width: 100%,
    inset: 8pt,
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let d = (:)
  let fields = old_block.fields()
  fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.abs
  }
  return block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == str {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == content {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

// Subfloats
// This is a technique that we adapted from https://github.com/tingerrr/subpar/
#let quartosubfloatcounter = counter("quartosubfloatcounter")

#let quarto_super(
  kind: str,
  caption: none,
  label: none,
  supplement: str,
  position: none,
  subcapnumbering: "(a)",
  body,
) = {
  context {
    let figcounter = counter(figure.where(kind: kind))
    let n-super = figcounter.get().first() + 1
    set figure.caption(position: position)
    [#figure(
      kind: kind,
      supplement: supplement,
      caption: caption,
      {
        show figure.where(kind: kind): set figure(numbering: _ => {
          let subfloat-idx = quartosubfloatcounter.get().first() + 1
          subfloat-numbering(n-super, subfloat-idx)
        })
        show figure.where(kind: kind): set figure.caption(position: position)

        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => block({
            num.slice(2) // I don't understand why the numbering contains output that it really shouldn't, but this fixes it shrug?
            [ ]
            it.body
          })

          quartosubfloatcounter.step()
          it
          counter(figure.where(kind: it.kind)).update(n => n - 1)
        }

        quartosubfloatcounter.update(0)
        body
      }
    )#label]
  }
}

// callout rendering
// this is a figure show rule because callouts are crossreferenceable
#show figure: it => {
  if type(it.kind) != str {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  kind = upper(kind.first()) + kind.slice(1)
  // now we pull apart the callout and reassemble it with the crossref name and counter

  // when we cleanup pandoc's emitted code to avoid spaces this will have to change
  let old_callout = it.body.children.at(1).body.children.at(1)
  let old_title_block = old_callout.body.children.at(0)
  let children = old_title_block.body.body.children
  let old_title = if children.len() == 1 {
    children.at(0)  // no icon: title at index 0
  } else {
    children.at(1)  // with icon: title at index 1
  }

  // TODO use custom separator if available
  // Use the figure's counter display which handles chapter-based numbering
  // (when numbering is a function that includes the heading counter)
  let callout_num = it.counter.display(it.numbering)
  let new_title = if empty(old_title) {
    [#kind #callout_num]
  } else {
    [#kind #callout_num: #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block,
    block_with_new_content(
      old_title_block.body,
      if children.len() == 1 {
        new_title  // no icon: just the title
      } else {
        children.at(0) + new_title  // with icon: preserve icon block + new title
      }))

  block_with_new_content(old_callout,
    block(below: 0pt, new_title_block) +
    old_callout.body.children.at(1))
}

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black, body_background_color: white) = {
  block(
    breakable: false, 
    fill: background_color, 
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"), 
    width: 100%, 
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%, 
      below: 0pt, 
      block(
        fill: background_color,
        width: 100%,
        inset: 8pt)[#if icon != none [#text(icon_color, weight: 900)[#icon] ]#title]) +
      if(body != []){
        block(
          inset: 1pt, 
          width: 100%, 
          block(fill: body_background_color, width: 100%, inset: 8pt, body))
      }
    )
}




#let article(
  title: none,
  subtitle: none,
  authors: none,
  keywords: (),
  date: none,
  abstract-title: none,
  abstract: none,
  thanks: none,
  cols: 1,
  lang: "en",
  region: "US",
  font: none,
  fontsize: 11pt,
  title-size: 1.5em,
  subtitle-size: 1.25em,
  heading-family: none,
  heading-weight: "bold",
  heading-style: "normal",
  heading-color: black,
  heading-line-height: 0.65em,
  mathfont: none,
  codefont: none,
  linestretch: 1,
  sectionnumbering: none,
  linkcolor: none,
  citecolor: none,
  filecolor: none,
  toc: false,
  toc_title: none,
  toc_depth: none,
  toc_indent: 1.5em,
  doc,
) = {
  // Set document metadata for PDF accessibility
  set document(title: title, keywords: keywords)
  set document(
    author: authors.map(author => content-to-string(author.name)).join(", ", last: " & "),
  ) if authors != none and authors != ()
  set par(
    justify: true,
    leading: linestretch * 0.65em
  )
  set text(lang: lang,
           region: region,
           size: fontsize)
  set text(font: font) if font != none
  show math.equation: set text(font: mathfont) if mathfont != none
  show raw: set text(font: codefont) if codefont != none

  set heading(numbering: sectionnumbering)

  show link: set text(fill: rgb(content-to-string(linkcolor))) if linkcolor != none
  show ref: set text(fill: rgb(content-to-string(citecolor))) if citecolor != none
  show link: this => {
    if filecolor != none and type(this.dest) == label {
      text(this, fill: rgb(content-to-string(filecolor)))
    } else {
      text(this)
    }
   }

  place(top, float: true, scope: "parent", clearance: 4mm)[
    #if title != none {
      align(center, block(inset: 2em)[
        #set par(leading: heading-line-height) if heading-line-height != none
        #set text(font: heading-family) if heading-family != none
        #set text(weight: heading-weight)
        #set text(style: heading-style) if heading-style != "normal"
        #set text(fill: heading-color) if heading-color != black

        #text(size: title-size)[#title #if thanks != none {
          footnote(thanks, numbering: "*")
          counter(footnote).update(n => n - 1)
        }]
        #(if subtitle != none {
          parbreak()
          text(size: subtitle-size)[#subtitle]
        })
      ])
    }

    #if authors != none and authors != () {
      let count = authors.len()
      let ncols = calc.min(count, 3)
      grid(
        columns: (1fr,) * ncols,
        row-gutter: 1.5em,
        ..authors.map(author =>
            align(center)[
              #author.name \
              #author.affiliation \
              #author.email
            ]
        )
      )
    }

    #if date != none {
      align(center)[#block(inset: 1em)[
        #date
      ]]
    }

    #if abstract != none {
      block(inset: 2em)[
      #text(weight: "semibold")[#abstract-title] #h(1em) #abstract
      ]
    }
  ]

  if toc {
    let title = if toc_title == none {
      auto
    } else {
      toc_title
    }
    block(above: 0em, below: 2em)[
    #outline(
      title: toc_title,
      depth: toc_depth,
      indent: toc_indent
    );
    ]
  }

  doc
}

#set table(
  inset: 6pt,
  stroke: none
)
#let brand-color = (
  background: rgb("#ddeaf1"),
  blue: rgb("#ddeaf1"),
  dark-grey: rgb("#222222"),
  foreground: rgb("#222222"),
  primary: black
)
#let brand-color-background = (
  background: color.mix((brand-color.background, 15%), (brand-color.background, 85%)),
  blue: color.mix((brand-color.blue, 15%), (brand-color.background, 85%)),
  dark-grey: color.mix((brand-color.dark-grey, 15%), (brand-color.background, 85%)),
  foreground: color.mix((brand-color.foreground, 15%), (brand-color.background, 85%)),
  primary: color.mix((brand-color.primary, 15%), (brand-color.background, 85%))
)
#set page(fill: brand-color.background)
#set text(fill: brand-color.foreground)
#set table.hline(stroke: (paint: brand-color.foreground))
#set line(stroke: (paint: brand-color.foreground))
#let brand-logo-images = (
  quarto-logo: (
    alt: "custom logo",
    path: "images/03.png"
  )
)
#let brand-logo = (
  small: (
    alt: "custom logo",
    path: "images/03.png"
  )
)
#set text()
#show heading: set text(font: ("Montserrat", "IBM Plex Sans KR", "Inter"), )
#show link: set text(fill: black, )

#set page(
  paper: "us-letter",
  margin: (x: 1.25in, y: 1.25in),
  numbering: "1",
  columns: 1,
)
#set page(background: align(right+top, box(inset: (right: 0.5in, top: 0.25in), image("images/03.png", width: 1in, alt: "Alternate alternate text"))))

#show heading: it => block(width: 100%)[
  #set text(weight: "extrabold", font: ("Noto Sans KR"))
  #(it.body)
]


#align(center)[
    #text("Seoncheol Park", font: ("Noto Sans KR"), weight:"black", size:30pt)
  ]

#set text(font: ("IBM Plex Sans", "IBM Plex Sans KR"))

= About Me
<about-me>
I am an Assistant Professor at the #link("http://math.hanyang.ac.kr/")[Department of Mathematics] and the #link("http://stat.hanyang.ac.kr/")[Department of Applied Statistics] at #link("https://www.hanyang.ac.kr/")[Hanyang University], South Korea. Prior to joining Hanyang University, I worked as an Assistant Professor at the #link("http://stat.chungbuk.ac.kr")[Department of Information Statistics] at #link("http://www.cbnu.ac.kr")[Chungbuk National University] for two years. I was also a Postdoctoral Research Fellow at the #link("https://www.pacificclimate.org/")[Pacific Climate Impacts Consortium] where I worked under the supervision of Professor #link("https://www.pacificclimate.org/about-pcic/people/francis-zwiers")[Francis Zwiers]. I received my Ph.D.~in Statistics from Seoul National University under the supervision of Professor #link("https://sites.google.com/site/heeseokoh")[Hee-Seok Oh], and I was a member of #link("https://sites.google.com/view/snumultiscale/home")[Multiscale Methods in Statistics Lab].

= Professional Experiences
<professional-experiences>
- Assistant Professor, #link("http://math.hanyang.ac.kr/")[Department of Mathematics] and #link("http://stat.hanyang.ac.kr/")[Department of Applied Statistics], #link("https://www.hanyang.ac.kr/")[Hanyang University], Seoul, Korea, March 2023 \~

- Assistant Professor, #link("http://stat.chungbuk.ac.kr")[Department of Information Statistics], #link("http://www.cbnu.ac.kr")[Chungbuk National University], Cheongju, Korea, March 2021 \~ February 2023.

- Post-Doctoral Research Fellow, #link("https://www.pacificclimate.org/")[Pacific Climate Impacts Consortium], #link("https://www.uvic.ca")[University of Victoria], Victoria, British Columbia, Canada, August 2019 \~ January 2021.

= Education
<education>
- Ph.D., Statistics, #link("http://www.snu.ac.kr")[Seoul National University], Seoul, Korea, 2019.

- B.S., Mathematical Sciences (Double Major with Management Sciences), #link("http://www.kaist.ac.kr")[KAIST], Daejeon, Korea, 2013.

= Research Interests
<research-interests>
- Spatio-temporal data analysis and extreme value statistics, application to environmental and public health data

= Academic Works
<academic-works>
= Publications
== International Journal Papers
<international-journal-papers>
\($zws^(*)$: Corresponding author, and $zws^(* *)$: Students I supervised)

#block[
+ H. Park, #strong[S. Park] and J. Kim$zws^(*)$ (2026+). #link("https://www.sciencedirect.com/science/article/pii/S0169207025001207")[Expectile-based probabilistic forecasting for spatio-temporal river network data.] #emph[International Journal of Forecasting], In Press. (I contributed equally to this work as joint first authors.)

+ S. Kang, K. Kim, Y. Kwon, S. Park, #strong[S. Park], H-Y. Shin, J. Kim$zws^(*)$ and H-S. Oh (2025). #link("https://link.springer.com/article/10.1007/s10687-024-00497-x")[Semiparametric approaches for the inference of univariate and multivariate extremes.] #emph[Extremes], #strong[28(1)], 123--148.

+ B. Lee$zws^(* *)$, H-D. Sou$zws^(*)$, P. Yeon, H. Lee, C-R. Park, S. Choi and #strong[S. Park]$zws^(*)$ (2024). #link("https://doi.org/10.3390/app14219988")[Seasonal characteristics of particulate matter by pollution source type and urban forest type.] #emph[Applied Sciences], #strong[14(21)], 9988.

+ S. Cho, D-K. Kim, M-C. Song, E. Lee, #strong[S. Park], D. Chung and J. Ha$zws^(*)$ (2024). #link("https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0301313")[Deciphering changes in the incidence of hemorrhagic stroke and cerebral venous sinus thrombosis during the coronavirus disease 2019 pandemic: a nationwide time-series correlation study.] #emph[PLOS ONE], #strong[19(10)], e0301313.

+ H. Lee, D. Kwon, #strong[S. Park], S-R. Park, , D. Chung and J. Ha$zws^(*)$ (2023). #link("https://doi.org/10.24171/j.phrp.2023.0050")[Temporal association between age-specific incidence of Guillain--Barré syndrome and SARS-CoV-2 vaccination; a nationwide time-series correlation study.] #emph[Osong Public Health and Research Perspectives], #strong[14(3)], 224--231.

+ J. Lee$zws^(* *)$ and #strong[S. Park]$zws^(*)$ (2023). #link("https://doi.org/10.29220/CSAM.2023.30.3.259")[Prediction of sharp change of particulate matter in Seoul via quantile mapping.] #emph[Communications for Statistical Applications and Methods], #strong[30(3)], 259--272.

+ B. Lee$zws^(* *)$, P. Yeon and #strong[S. Park]$zws^(*)$ (2022). #link("https://www.mdpi.com/1660-4601/19/24/16403")[The factors and relationships influencing urban hiking exercise characteristics after COVID-19 occurrence: at Seoul Metropolitan Area and in their 20s and 30s.] #emph[International Journal of Environmental Research and Public Health], #strong[19(24)], 16403.

+ S. Cho, Y-M. Kim, G. Seong, S. Park, #strong[S. Park], S-E. Lee and Y. Park$zws^(*)$ (2022). #link("https://doi.org/10.4178/epih.e2022065")[Analysis of on-ship transmission through cases of COVID-19 mass outbreak on Republic of Korea Navy Amphibious Warfare ship.] #emph[Epidemiology and Health], #strong[44], e2022065.

+ S. Lee, #strong[S. Park] and Y. Lim$zws^(*)$ (2022). #link("https://doi.org/10.29220/CSAM.2022.29.3.319")[Prediction of extreme PM2.5 concentrations via extreme quantile regression.] #emph[Communications for Statistical Applications and Methods], #strong[29(3)], 319--331.

+ #strong[S. Park] and H-S. Oh$zws^(*)$ (2022). #link("https://rss.onlinelibrary.wiley.com/doi/10.1111/rssc.12542")[Lifting scheme for streamflow data in river networks.] #emph[Journal of the Royal Statistical Society: Series C (Applied Statistics)], #strong[71(2)], 467--490.

+ J. Kim, #strong[S. Park]$zws^(*)$, J. Kwon, Y. Lim and H-S. Oh (2021). #link("https://link.springer.com/article/10.1007/s10687-020-00404-0")[Estimation of spatio-temporal extreme distribution using a quantile factor model.] #emph[Extremes], #strong[24(1)], 177--195.

+ #strong[S. Park]$zws^(*)$, J. Kwon, J. Kim and H-S. Oh (2018). #link("https://link.springer.com/article/10.1007/s10687-018-0323-y")[Prediction of extremal precipitation by quantile regression forests: from SNU Multiscale team.] #emph[Extremes], #strong[21(3)], 463--476.

+ #strong[S. Park] and H-S. Oh$zws^(*)$ (2017). #link("http://dx.doi.org/10.1007/s00477-016-1376-6")[Spatio-temporal analysis of particulate matter extremes in Seoul: use of multiscale approach.] #emph[Stochastic Environmental Research and Risk Assessment], #strong[31(9)], 2401--2414.

]
= Presentations
== Talks and Posters
<talks-and-posters>
#block[
+ #link("https://github.com/SeoncheolPark/seoncheolpark.github.io/blob/master/files/250724_Taiwan.pdf")[Statistical Modeling of Water Quality Data on River Networks], #link("https://www3.stat.sinica.edu.tw/wss2025/")[#emph[2025 Workshop on Spatial Statistics and Related Fields]], Taipei, Taiwan, July 2025.

+ #link("https://webpageprodvm.ntu.edu.tw/IASC-ARS_Interim_2024/cp.aspx?n=190889")[Clustering of Mountain Hiking GPS-Trajectory Data], #emph[IASC-ARS Interim Conference 2024], Taipei, Taiwan, December 2024.

+ Estimation of marine heatwaves in the East Sea: The extreme value generalized additive model approach, #emph[Asia Oceania Geosciences Society (AOGS) 2024 21#super[th] Annual Meeting], Pyeongchang, Korea, June 2024.

+ Spatial statistical models for environmental data in Korea, #emph[Japanese Joint Statistical Meeting 2022], Tokyo, Japan, September 2022.

+ Lifting scheme for streamflow data in river networks, #emph[2022 The Korean Data Information Science Society Spring Conference], Busan, Korea, May 2022.

+ Lifting scheme for streamflow data in river networks, #emph[2021 The Korean Statistical Society Autumn Conference], Seoul, Korea, November 2021.

+ Lifting scheme for streamflow data in river networks, #emph[Bernoulli-IMS 10#super[th] World Congress in Probability and Statistics], Seoul, Korea, July 2021.

+ A new approach for modelling the spatial extent of agricultural drought, #emph[The 55#super[th] Canadian Meteorological and Oceanographic Society (CMOS) Congress], Victoria, Canada, June 2021.

+ Multiresolution analysis for spatio-temporal data, #emph[5#super[th] Institute of Mathematical Statistics Asia Pacific Rim Meeting], Singapore, Singapore, June 2018.

+ #link("http://www.eva2017.nl/program/scipro/friday/index.html")[Prediction of extremal precipitation: the use of quantile regression forests], #emph[10#super[th] Extreme Value Analysis Conference], Delft, Netherlands, June 2017.

+ Multiresolution analysis for spatio-temporal data. #emph[2017 The Korean Statistical Society Spring Conference], Seoul, Korea, May 2017.

+ Multiscale modeling for particulate matter extremes. #emph[2015 The Korean Statistical Society Autumn Conference], Yongin, Korea, November 2015.

+ #link("http://data.si.re.kr/node/623")[Multiscale modeling for particulate matter extremes in Seoul]. #emph[The Seoul Institute Research Competition 2015], Seoul, Korea, November 2015.

+ Prediction of extreme particulate matter : the use of quantile regression forests. #emph[2014 The Korean Statistical Society Autumn Conference], Seoul, Korea, November 2014.

]
== With My Students
<with-my-students>
#block[
+ 종단 오믹스 자료 발현 분석을 위한 R 패키지 개발 (with Haju Kang), #emph[2025 The Korean Statistical Society Winter Conference], Seoul, Korea, December 2025.

+ Adaptive Boosting on Linear Networks (with Seungyeon Lim), #emph[2025 The Korean Statistical Society Summer Conference], Gyeongju, Korea, June 2025.

+ Outlier Detection Followed by Fault Type Prediction: Two-Stage Approach (with Min Ju Kim and Seungyeon Lim), #emph[2025 The Korean Statistical Society Summer Conference], Gyeongju, Korea, June 2025.

+ Prediction of sharp change of particulate Matter in Seoul via quantile mapping (with Jeongeun Lee), #emph[2022 The Korean Statistical Society Summer Conference], Seoul, Korea, June 2022.

]
= Awards
#block[
+ Excellence award (3rd place), KSIAM-MathWorks problem challenge, #emph[Korea Society for Industrial and Applied Mathematics], Sep 2018.

+ Best oral presentation award (Pre-PhD): Multiresolution analysis for spatio-temporal data. #emph[The Korean Statistical Society], May 2017.

+ Excellence award, #link("http://data.si.re.kr/node/623")[The Seoul Institute Research Competition 2015], #emph[The Seoul Institute], November 2015.

]
= Grants
== International or Domestic Research Foundations
<international-or-domestic-research-foundations>
- Outstanding Young Scientist Grants (우수신진연구), #emph[Korean Ministry of Science and ICT], April 2024 \~ March 2027.

- Basic Science Research Program (기본연구), #emph[Korean Ministry of Education], June 2021 \~ August 2024.

== University Grants
<university-grants>
- 서울-ERICA 공동연구 지원사업, #emph[Hanyang University (HYU)], June 2024 \~ May 2025.

- 신임교원 정착 연구 지원사업, #emph[Hanyang University (HYU)], March 2023 \~ August 2024.

- 신진교수 연구비 지원사업, #emph[Chungbuk National University (CBNU)], March 2021 \~ August 2022.

== Scholarship
<scholarship>
- Sohn Dong-Joon Scholarship, #emph[College of Natural Sciences (SNU)], May 2016 \~ August 2019.

= Services
== Referee
<referee>
- Theoretical and Applied Climatology

- Annals of Applied Statistics

- Journal of Agricultural, Biological and Environmental Statistics

- Extremes

- Stochastic Environmental Research and Risk Assessment

- Computational Statistics

- Journal of the Korean Statistical Society

- Communications for Statistical Applications and Methods

- Computational Statistics and Data Analysis

- Scientific Reports

- Epidemiology and Health

== Professional Services
<professional-services>
- 한국통계학회 평의원

- 서울특별시 스마트도시위원회 위원

= Teaching
== Hanyang University
<hanyang-university>
=== Undergraduate Courses
<undergraduate-courses>
- Statistical Computing / Statistical Methods for Data Analysis (2023 Fall, 2024 Fall, 2025 Fall)

- Introduction to Regression Analysis (2024 Spring, 2026 Spring)

- Artificial Intelligence and Machine Learning (2023 Spring, 2024 Spring, 2025 Spring)

=== Graduate Courses
<graduate-courses>
- Regression Analysis (2024 Spring, 2026 Spring)

- Nonparametric Statistics (2024 Fall)

- Linear Models (2025 Spring)

- Statistical Data Science (2023 Fall, 2025 Fall)

- Seminar in Recent Development of Applied Statistics (2023 Spring)

== Chungbuk National University
<chungbuk-national-university>
=== Undergraduate Courses
<undergraduate-courses-1>
- Elementary Probability Theory (2022 Spring)

- Regression Analysis (2021 Spring, 2022 Spring)

- Statistical Simulation (2021 Spring)

- Insurance Statistics (2021 Fall)

- Financial Statistics (2021 Fall)

- Financial and Insurance Statistics (2022 Fall)

- Spatial Statistics (2022 Fall)

=== Graduate Courses
<graduate-courses-1>
- Topics in Regression Analysis (2022 Spring)

- Statistical Methodology (2021 Spring)

- Machine Learning Methodology (2022 Fall)

- Deep Learning (2021 Fall)

= Contact Me
<contact-me>
#link("mailto:pscstat@hanyang.ac.kr")[pscstat\@hanyang.ac.kr] or #link("mailto:pscstat@gmail.com")[pscstat\@gmail.com]
