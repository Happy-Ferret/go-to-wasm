package main

func ack(m, n int) int {
	if m == 0 {
		return n+1
	} else if m > 0 {
		if n == 0 {
			return ack(m-1,1)
		} else if n > 0 {
			return ack(m-1,ack(m,n-1))
		}
	}
	return -1
}

func main() {
	println(ack(3,13))
}
