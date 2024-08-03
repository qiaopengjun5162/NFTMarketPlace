# NFTMarket

## 1. NFTMarket简介

NFTMarket是一个基于以太坊区块链的NFT市场，用户可以在这里购买、出售和交易NFT。NFTMarket使用Solidity语言编写智能合约，并使用Web3.js库与以太坊网络进行交互。

## 2. NFTMarket功能

NFTMarket具有以下功能：

- 创建NFT：用户可以创建自己的NFT，并将其添加到市场。
- 购买NFT：用户可以购买市场上的NFT。
- 出售NFT：用户可以将自己的NFT出售给其他用户。


$$
利息 = 本金 * 利率 \\

本息 = 本金 + 本金 * 利率 = 本金 * (1 + 利率) \\
$$
假设每年的利率不一样，是浮动的，怎么计算？ 复利
$$
最终要还的本息 = 本金 * (1 + R1) * (1 + R2) * (1 + R3) ...
$$
从第五年开始借款到第十年还款，支付的本息
$$
\begin{align}
本息 &= 本金 * (1 + R6) * ... * (1 + R10) \\
\\
&= \frac{(1 + R1) * ... * (1 + R5) * (1 + R6) * ... * (1 + R10)}{(1 + R1) * ... * (1 + R5)}
\end{align}
$$
在每次发生借贷业务时，利率 Ri 会发生变化，把每次的变化都累积记录
$$
\begin{align}
\text{本息} &= \text{本金} \cdot (1 + R6) \cdot \ldots \cdot (1 + R10) \\
&= \frac{(1 + R1) \cdot \ldots \cdot (1 + R5) \cdot (1 + R6) \cdot \ldots \cdot (1 + R10)}{(1 + R1) \cdot \ldots \cdot (1 + R5)}
\end{align}
$$

$$
R0...i = (1 + R1) \cdot \ldots \cdot (1 + R5) \cdot (1 + R6) \cdot \ldots \cdot (1 + R10)
$$

