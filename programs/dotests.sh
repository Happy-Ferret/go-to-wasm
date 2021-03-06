#!/bin/bash

pad=$(printf '%0.1s' "."{1..80})
GOC=../src/main.native

passed=0
total=0

echo "== Testing $1 ================================"

case $1 in

"lex"|"parse")
files=$(find $1 | egrep  "\.invalid$|\.valid$" | sort)
;;
"pretty")
files=$(ls $1/*.go $1/*.valid)
;;
"weed")
files=$(find "parse" | egrep  "\.invalid$|\.valid$" | sort)
;;
"type")
files=$(find "type" | egrep  "\.invalid$|\.valid$" | sort)
;;
"pptype")
files=$(find "parse/valid"  | egrep  "\.valid$" | sort)

esac

for f in $files; do
  fname=$(echo $f | cut -f 1 -d '.')
  ext="${f##*.}" 

  expected=0

  if [ $1 = "pretty" ]
  then
      $GOC $1 < $f > "$fname.pretty"
      $GOC $1 "$fname.pretty" |  diff $fname.pretty - > /dev/null 2>&1
  elif [ $1 = "pptype" ]
  then
      $GOC -pptype type "$f" > /dev/null
      $GOC -pptype type "$fname.pptype.go" > /dev/null
      diff $fname.pptype.go $fname.pptype.pptype.go > /dev/null 2>&1
  else
    if [ -f "$fname.expected" ]
    then
	error=$($GOC $1 < $f 2>&1 1>/dev/null)
	$GOC $1 < $f 2>/dev/null | diff $fname.expected - > /dev/null 
    else
      if [ $ext = "invalid" ]
      then
        expected=1
      fi
      { error=$($GOC $1 < $f 2>&1 1>/dev/null); }
    fi
  fi

  #$GOC $1 < $f > /dev/null 2>&1

  result=$?
  if [ $result -eq $expected ] # 0 or 1
  then
    if [ $ext = "invalid" ]
    then
      printf '%*.*s' 0 70 "$f $pad"
      echo -e " [\e[32mpassed\e[39m]"
      echo "$error"
      echo ""
    fi
    passed=$((passed+1))
  elif [ $result -eq $((1 - $expected)) ] # 0 or 1
  then
    printf '%*.*s' 0 70 "$f $pad"
    echo -e " [\e[31mfailed\e[39m]"
    echo "$error"
    echo ""
  else
    printf '%*.*s' 0 70 "$f $pad"
    echo -e " [\e[31mfailed\e[39m]"
    echo "There was something wrong with the diff command"
  fi
  total=$((total+1))
done

echo -e "\nPassed: $passed/$total"
