#!/bin/sh
# BUG MAKE SURE EACH CSV FILES HAVE NO DUPLICATES

cd ./csv

alias bemenu="bemenu -i -c -l 20 -B 3 -W 0.25 -p \">\" --fn unscii 12 --cw 2 --cf \"#eceff4\" --bdr \"#5e81ac\" --tb \"#2e3440\" --tf \"#eceff4\" --nb \"#2e3440\" --nf \"#4c566a\" --ab \"#2e3440\" --af \"#4c566a\" --fb \"#2e3440\" --ff \"#eceff4\" --hb \"#2e3440\" --hf \"#eceff4\""

nfiles=$(ls -1 | wc -l)

get_column () {
	output=$(echo $header | awk -v para=$2 '
		BEGIN{
		  FS=","
		}
		{ 
		  for(i=1;i<=NF;i++){
		     if($i==para){
		        print i
		     }
		  }
		}
	')
	export $1="$output"
}

convert_ipa () {
	ipa=$(echo $ipa | sed -e '
		s/ˈ/\\textprimstress{}/g;
		#s/ˈ/"/g;
		s/ˌ/\\textsecstress{}/g; 
		#s/ˌ/""/g; 
		s/i̯/\\textsubarch{i}/g;
		s/ɪ̯/\\textsubarch{I}/g;
		s/ɪ/I/g;
		s/ʊ̯/\\textsubarch{U}/g;
		s/ʊ/U/g;
		s/ɐ̯/\\textsubarch{5}/g;
		s/ɐ/5/g;
		s/n̩/\\s{n}/g;
		s/l̩/\\s{l}/g;
		s/ç/\\c{c}/g;
		s/ø/\\o{}/g;
		s/ŋ/\\ng{}/g;
		s/œ/\\oe{}/g;
		s/t͡s/\\t{ts}/g;
		s/ʦ/\\texttslig{}/g;
		s/p͡f/\\t{pf}/g;
		s/ɑ̃/\\~{A}/g;
		s/ː/:/g;
		s/ɛ/E/g;
		s/ʁ/K/g;
		s/ʀ/\\textscr{}/g;
		s/ʃ/S/g;
		s/ɔ̃/\\~{O}/g;
		s/ɔ/O/g;
		s/ɡ/g/g;
		s/ə/@/g;
		s/ʏ/Y/g;
		s/ʔ/P/g;
	')
	ipa="\\textipa{$ipa}"
	ipa=$(echo $ipa | sed -e 's/\\/\\\\/g')
}

data=$(
	for (( i = 1; i <= $nfiles; i++ ))
	do
		loop_file=$(ls -1 |  head -n "$i" | tail -n 1)
		filename=${loop_file%.*} ; default="${filename^}"
		header=$(head -n 1 $loop_file)

		if [[ $loop_file == "substantiv.csv" ]] ; then
			get_column "col" $default
			get_column "gcol" "Genus"
			get_column "pcol" "Plural"
			tail -n +2 $loop_file | awk -v c=$col -v g=$gcol -v p=$pcol '
				BEGIN{
					FS=","
				}{
					if($c==""){print "die "$p}
					else{print $g" "$c}
				}
			' | sed -e "s/^/$loop_file:$default /"
		else
			if [[ $loop_file == "verb.csv" ]] ; then
				get_column "col" $default
				get_column "tcol" "trennbar"
				tail -n +2 $loop_file | awk -v c=$col -v t=$tcol '
					BEGIN{
						FS=","
					}{
						if($t=="-"){print $c}
						else{print $c" "$t}
					}
				' | sed -e "s/^/$loop_file:$default /" | sed -e 's/1/(trennbar)/; s/0/(nicht trennbar)/'
			else
				get_column "col" $default
				data=$(tail -n +2 $loop_file | sed -e "s/^/$loop_file:/")
				tail -n +2 $loop_file | awk -v c=$col -F'[,]' '{print $c}' | sed -e "s/^/$loop_file:$default /"
			fi
		fi
	done
)

dataH=$(echo "$data" | awk -F'[:]' '{print $2}')

choosen=$(echo "$dataH" | bemenu)
[[ -z $choosen ]] && exit
row=$(echo "$dataH" | grep -Fnx "$choosen" | awk -F'[:]' '{print $1}')
choosen_file=$(echo "$data" | head -n "$row" | tail -n 1 | awk -F'[:]' '{print $1}')
data_row=$(echo "$data" | grep "^$choosen_file:" | grep -Fnx "$(echo $choosen | sed -e "s/^/$choosen_file:/")" | awk -F'[:]' '{print $1}')
data=$(cat $choosen_file | tail -n +2 | head -n "$data_row" | tail -n 1)

header=$(head -n 1 $choosen_file)
get_column "icol" "IPA"

nipa=$(echo "$icol" | wc -l)
if [[ $nipa != 1 ]] ; then
	for (( i = 1; i <= $nipa; i++ ))
	do
		loop_col=$(echo "$icol" |  head -n "$i" | tail -n 1)
		ipa=$(echo $data | awk -v i=$loop_col -F'[,]' '{print $i}')
		convert_ipa
		data=$(echo $data | sed -e "s/\[/\\\\att{/g; s/\]/}/g; s/1/True/; s/0/False/; s/[^,]*/${ipa//\//\\/}/$loop_col;")
	done
else
	ipa=$(echo $data | awk -v i=$icol -F'[,]' '{print $i}')
	convert_ipa
	data=$(echo $data | sed -e "s/\[/\\\\att{/g; s/\]/}/g; s/1/True/; s/0/False/; s/[^,]*/${ipa//\//\\/}/$icol;")
fi
data=$(echo $data | sed -e 's/\\textipa{\([a-zA-Z0-9{}@":\~]*\)\/\([a-zA-Z0-9{}@":\~]*\)}/\\makecell[l]{\\textipa{\1} \\\\ \\textipa{\2}}/g' -e 's/\([a-zA-ZäöüÄÖÜß]*\)\/\([a-zA-ZäöüÄÖÜß]*\)\,/\\makecell[l]{\1 \\\\ \2}\,/g')

if [[ $choosen_file == "verb.csv" ]] ; then
	echo "$(
		echo $header | awk -F'[,]'	'{print $1","										$2","					$3","					$4","	"Perfekt,"						"Präsen,"	"Konjunktiv I,"	"Präteritum,"	"Konjunktiv II"}' && 
		echo $data | awk -F'[,]'	'{print "\\multirow{6}{*}{"$1"},\\multirow{6}{*}{"	$2"},\\multirow{6}{*}{"	$3"},\\multirow{6}{*}{"	$4"},\\multirow{6}{*}{"$29" "$30"},"	$5","		$11","			$17","			$23	}'
		echo $data | awk -F'[,]'	'{print 																							",,,,"							","		$6","		$12","			$18","			$24	}'
		echo $data | awk -F'[,]'	'{print																								",,,,"							","		$7","		$13","			$19","			$25	}'
		echo $data | awk -F'[,]'	'{print																								",,,,"							","		$8","		$14","			$20","			$26	}'
		echo $data | awk -F'[,]'	'{print																								",,,,"							","		$9","		$15","			$21","			$27	}'
		echo $data | awk -F'[,]'	'{print																								",,,,"							","		$10","		$16","			$22","			$28	}'
	)" > ~/.cache/vokab/vokab.csv
else
	echo "$(echo $header && echo $data)" > ~/.cache/vokab/vokab.csv
fi
#cat ~/.cache/vokab/vokab.csv
#exit

cat << EOF > ~/.cache/vokab/vokab.tex
\\documentclass[varwidth=\\maxdimen,margin=5mm]{standalone}

\\usepackage{tipa}
\\usepackage[l3]{csvsimple}
\\usepackage{booktabs}
\\usepackage[ngerman]{babel}
\\usepackage{multirow}
\\usepackage{makecell}
\\usepackage{xcolor}
	\\definecolor{Aurora1}{HTML}{bf616a}

\\newcommand{\\att}[1]{\\textcolor{Aurora1}{#1}}

\\begin{document}
{\\Huge \\bfseries $choosen}
\\begin{table}[h]
\\csvautobooktabular{/home/pumpko/.cache/vokab/vokab.csv}
\\end{table}
\\end{document}
EOF

pdflatex -shell-escape -output-directory=/home/pumpko/.cache/vokab ~/.cache/vokab/vokab.tex && zathura ~/.cache/vokab/vokab.pdf
