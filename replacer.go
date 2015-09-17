package main

import (
    "bufio"
    "bytes"
    "fmt"
    "io"
    "os"
    "strings"
    "unsafe"
    "flag"
)

/**
 * Replacer: copies file whilst replacing a given string
 * Example (not compiled): go run replacer.go /path/to/big/input.txt replaced.txt password '********'
 * Reads input.txt, copies it to the PWD, replasing all occurences of "password" with ********
 *
 * There is an optional -unsafe flag to use byte-to-string conversion via unsafe pointers, too:
 * ./replace -unsafe in.log out.log search replace
 *
 */

//convert read buffer to string
func bufferToString(buffer *bytes.Buffer, unsafePtr *bool) string {
    defer buffer.Reset()//ensure buffer is reset
    if !*unsafePtr {
        return buffer.String()
    }
    bb := buffer.Bytes()
    s := *(*string)(unsafe.Pointer(&bb))
    return s
}

//help, or invalid flag
func usage() {
    fmt.Printf("Usage of %s:\n", os.Args[0])
    fmt.Println("    [-unsafe] inputfile outfile search-string replace-string")
    fmt.Println("\nAvailable options:")
    flag.PrintDefaults()
    fmt.Printf("\nThe -unsafe flag can increase performance. The performance gain is, however, marginal\n")
    fmt.Println("and is generally not worth the added risks, hence the name: unsafe")
}

//open files taken from argv
func openFiles(argv []string) (*os.File, *os.File) {
    inFile, err := os.Open(argv[0])
    if err != nil {
        panic(err)
    }

    outFile, err := os.Create(argv[1])
    if err != nil {
        inFile.Close()//close here
        panic(err)
    }
    return inFile, outFile
}

//open reader and writer
func openReadWrite(inFile *os.File, outFile *os.File) (*bufio.Reader, *bufio.Writer) {
    return bufio.NewReader(inFile), bufio.NewWriter(outFile)
}

func getArguments() (*bool, []string) {
    unsafePtr := flag.Bool("unsafe", false, "use unsafe byte-to-string conversion")
    helpPtr := flag.Bool("help", false, "Display help message")
    flag.Usage = usage;
    flag.Parse()
    if *helpPtr {
        usage()
        return nil, flag.Args()
    }
    argv := flag.Args()
    if len(argv) != 4 {
        fmt.Fprintln(os.Stderr, "Expected 4 arguments")
        return nil, argv
    }
    return unsafePtr, argv
}

//main function
func main() {
    unsafePtr, argv := getArguments()
    if unsafePtr == nil {
        return
    }
    file, f := openFiles(argv)
    defer file.Close()
    defer f.Close()

    reader, w := openReadWrite(file, f)

    buffer := bytes.NewBuffer(make([]byte, 0))
    var (
        part   []byte
        prefix bool
    )
    for {
        var err error
        if part, prefix, err = reader.ReadLine(); err != nil {
            if err != io.EOF {
                fmt.Fprintln(os.Stderr, "error reading input file: ", err)
            } else {
                fmt.Println("File processed")
            }
            break
        }
        buffer.Write(part)
        buffer.WriteString("\n") //add the \n before writing to the new file:wq
        if !prefix {
            s := bufferToString(buffer, unsafePtr)
            _, err := w.WriteString(strings.Replace(s, argv[2], argv[3], -1))
            if err != nil {
                fmt.Fprintln(os.Stderr, "error writing file: ", err)
                break
            }
            w.Flush()
        }
    }

}
