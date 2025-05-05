Stable Features
1. Relative Stability : Anchored or Pegged to US dollar = $1
        1. Chianlink Pricefeed
        2. Set a function to exchange ETH and BTC ==> $$
2. (Stability Mechanisim) Minting : Algorithmic (Decentralized)
        1. People can only mint Stablecoin with enough collatral (coded)
3. Collatral Type : Exogenous (Crypto)
    1. wETH
    2. wBTC

4. There are no way If the user deposited the collateral and want to withdraw the collateral without minting the TDSC (Decentralized Stable coin). User should be able to withdraw the collateral without minting the TDSC. 

5. After liquidation we are not reducing the TDSC from user's wallet on chain, we are just updating the TDSC balance in our state variable and we are reducing the TDSC balance from Liquidation user's wallet on chain but not updating our state variable.