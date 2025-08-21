package main

import (
	"fmt"
	"io/ioutil"
	"log"
	"os"
)

const blockSize = 128

func main() {
	if len(os.Args) != 3 {
		log.Fatalf("Usage: %s <input EDID file> <output EDID file>\n", os.Args[0])
	}
	inFile, outFile := os.Args[1], os.Args[2]

	data, err := ioutil.ReadFile(inFile)
	if err != nil {
		log.Fatalf("Failed to read %s: %v", inFile, err)
	}

	if len(data)%blockSize != 0 {
		log.Fatalf("File size (%d bytes) is not a multiple of %d", len(data), blockSize)
	}

	numBlocks := len(data) / blockSize
	fmt.Printf("Found %d EDID block(s).\n", numBlocks)

	var fixed bool

	for i := 0; i < numBlocks; i++ {
		start := i * blockSize
		block := data[start : start+blockSize]
		tag := block[0]

		// For CTA-861 (tag 0x02) extension blocks, do not change anything.
		if i > 0 && tag == 0x02 {
			total := 0
			for j := 0; j < blockSize; j++ {
				total += int(block[j])
			}
			fmt.Printf("Block %d (CTA-861 extension): total sum = %d (mod256 = %d), checksum byte = 0x%02x (skipping fix)\n",
				i, total, total%256, block[blockSize-1])
			continue
		}

		// Compute overall block sum
		total := 0
		for j := 0; j < blockSize; j++ {
			total += int(block[j])
		}
		mod := total % 256
		fmt.Printf("Block %d (tag 0x%02x): total sum = %d (mod256 = %d)\n", i, tag, total, mod)
		if mod == 0 {
			fmt.Printf("Block %d is valid.\n", i)
			continue
		}

		// For non-DisplayID blocks, the last byte is the checksum.
		// For DisplayID blocks (tag 0x70) we must not touch the stored checksum (last byte)
		// but instead adjust one of the filler bytes – here we choose the byte at offset 126.
		fixOffset := blockSize - 1 // normally fix the checksum field
		if i > 0 && tag == 0x70 {
			fixOffset = blockSize - 2 // for DisplayID, adjust the filler just before the checksum
		}
		fixIndex := start + fixOffset

		// Calculate what the fixable byte should be.
		// Let sumExcluding be the sum of all bytes except the one we’re allowed to change.
		sumExcluding := total - int(data[fixIndex])
		newVal := (256 - (sumExcluding % 256)) % 256

		fmt.Printf("Block %d: adjusting filler byte at index %d (offset %d): old value = 0x%02x, new value = 0x%02x\n",
			i, fixIndex, fixOffset, data[fixIndex], newVal)
		data[fixIndex] = byte(newVal)

		// Verify the new total
		newTotal := 0
		for j := 0; j < blockSize; j++ {
			newTotal += int(data[start+j])
		}
		fmt.Printf("Block %d: new total sum = %d (mod256 = %d)\n", i, newTotal, newTotal%256)
		fixed = true
	}

	if !fixed {
		fmt.Println("No checksum fixes needed.")
	}

	if err = ioutil.WriteFile(outFile, data, 0644); err != nil {
		log.Fatalf("Failed to write %s: %v", outFile, err)
	}
	fmt.Printf("Fixed file written to %s\n", outFile)
}
