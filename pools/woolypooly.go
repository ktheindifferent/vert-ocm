package pools

import (
	"fmt"
	"time"

	"github.com/vertcoin-project/one-click-miner-vnext/util"
)

var _ Pool = &Woolypooly{}

type Woolypooly struct {
	Address           string
	LastFetchedPayout time.Time
	LastPayout        uint64
}

func NewWoolypooly(addr string) *Woolypooly {
	return &Woolypooly{Address: addr}
}

func (p *Woolypooly) GetPendingPayout() uint64 {
	jsonPayload := map[string]interface{}{}
	err := util.GetJson(fmt.Sprintf("https://api.woolypooly.com/api/vtc-1/account/%s", p.Address), &jsonPayload)
	if err != nil {
		return 0
	}
	balance, ok := jsonPayload["balance"].(float64)
	if !ok {
		return 0
	}
	balance *= 100000000
	return uint64(balance)
}

func (p *Woolypooly) GetStratumUrl() string {
	return "stratum+tcp://pool.woolypooly.com:3102"
}

func (p *Woolypooly) GetUsername() string {
	return p.Address
}

func (p *Woolypooly) GetPassword() string {
	return "x"
}

func (p *Woolypooly) GetID() int {
	return 7
}

func (p *Woolypooly) GetName() string {
	return "WolyPooly.com"
}

func (p *Woolypooly) GetFee() float64 {
	return 0.90
}

func (p *Woolypooly) OpenBrowserPayoutInfo(addr string) {
	util.OpenBrowser(fmt.Sprintf("https://woolypooly.com/en/coin/vtc?wallet=%s", addr))
}
