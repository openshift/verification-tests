package main

import (
	"bufio"
	"fmt"
	"log"
	"os"
	"strings"
)

const fileSuffix = ".tmp"

func logErr(e error) {
	if e != nil {
		log.Fatal(e)
	}
}

// readFile reads from a .feature file and write the lines into map[int]string
// int is the line number, starts with 0
// string is the line content
func readFile(filePath string, initLines *map[int]string) {
	f, err := os.Open(filePath)
	logErr(err)
	defer f.Close()

	scanner := bufio.NewScanner(f)
	for i := 0; scanner.Scan(); i++ {
		(*initLines)[i] = scanner.Text()
	}

	err = scanner.Err()
	logErr(err)
}

// isScenario check if specific line starts with "Scenario"
// after trim spaces
func isScenario(line string) bool {
	return strings.HasPrefix(strings.TrimSpace(line), "Scenario")
}

// isTag check if specific line starts with "@" after
// trim spaces
func isTag(line string) bool {
	return strings.HasPrefix(strings.TrimSpace(line), "@")
}

// isTagUpgChk check if specific line starts with "@upgrade-check"
// after trim spaces
func isTagUpgChk(line string) bool {
	return strings.HasPrefix(strings.TrimSpace(line), "@upgrade-check")
}

// parseTags check lines that are tags from map initMap,
// and save those missing tags in map addMap,
// and save those partial match lines in map sedMap
func parseTags(initMap, addMap, sedMap *map[int]string) {
	var preLine, postLine int
	for curLine := len(*initMap) - 1; curLine >= 0; curLine-- {
		if isScenario((*initMap)[curLine]) {
			//fmt.Printf("line %v, %v\n", curLine, (*initMap)[curLine])
			preLine, postLine = curLine, preLine
			if preLine != postLine && postLine != 0 {
				if strings.HasPrefix((*initMap)[preLine], (*initMap)[postLine]) {
					//fmt.Printf("paired scenarios %v, %v\n", preLine, postLine)
					for postTagLine := postLine - 1; postTagLine > 0; postTagLine-- {
						tagExist := false
						postTag := strings.TrimSpace((*initMap)[postTagLine])
						if !isTag(postTag) {
							break
						} else if isTagUpgChk(postTag) {
							continue
						}
						for preTagLine := preLine - 1; preTagLine > 0; preTagLine-- {
							preTag := strings.TrimSpace((*initMap)[preTagLine])
							if !isTag(preTag) {
								break
							}
							if preTag == postTag {
								tagExist = true
								break
							} else if strings.HasSuffix(postTag, preTag) {
								tagExist = true
								fmt.Println("Not paired tags, preTag is partial of the postTag, sed the line")
								fmt.Printf("\tpostTag: %v\n\tpreTag: %v\n",
									(*initMap)[postTagLine], (*initMap)[preTagLine])
								(*sedMap)[preTagLine] = (*initMap)[postTagLine]
							}
						}
						if !tagExist {
							extraLines := len(*addMap)
							fmt.Printf("Not paired tags, on line %v, tags: '%v'\n", postTagLine+1, postTag)
							(*addMap)[postTagLine-postLine+preLine+extraLines+1] = (*initMap)[postTagLine]
						}
					}
					postLine = preLine
				}
			}
		}
	}
}

// writeFile writes to a file, by reading from map[int]string
// for a specific line,
// if sedMap is not empty, write that line.
// if addMap is not empty, add that line, and then add the line from orimap.
func writeFile(filepath string, initMap, addMap, sedMap *map[int]string) {
	f, err := os.Create(filepath + fileSuffix)
	logErr(err)
	defer f.Close()
	for i := 0; i < len(*initMap); i++ {
		if (*sedMap)[i] != "" {
			fmt.Fprintln(f, (*sedMap)[i])
			logErr(err)
			continue
		}
		if (*addMap)[i] != "" {
			fmt.Fprintln(f, (*addMap)[i])
			logErr(err)
		}
		fmt.Fprintln(f, (*initMap)[i])
		logErr(err)
	}
}

func main() {
	filePath := os.Args[1]
	initLines, addLines, sedLines := make(map[int]string),
		make(map[int]string),
		make(map[int]string)
	readFile(filePath, &initLines)
	parseTags(&initLines, &addLines, &sedLines)
	writeFile(filePath, &initLines, &addLines, &sedLines)
	os.Rename(filePath+fileSuffix, filePath)
}
