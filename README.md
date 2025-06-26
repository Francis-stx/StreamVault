# StreamVault 💧

A decentralized streaming payment system built on Stacks blockchain that enables fans to support their favorite creators through automatic micropayments over time.

## 🎯 Overview

StreamVault allows supporters to create payment streams that automatically distribute STX tokens to creators over a specified duration. Instead of one-time donations, fans can set up continuous support that flows to creators block by block.

## ✨ Features

- **Streaming Payments**: Create payment streams with customizable duration and amount
- **Automatic Distribution**: Payments flow automatically based on block height
- **Creator Withdrawals**: Creators can withdraw earned funds at any time
- **Stream Management**: Supporters can cancel streams and recover remaining funds
- **Platform Fees**: Configurable platform fee system (default 2.5%)
- **Transparent Tracking**: Full visibility of stream status and earnings

## 🔧 Technical Specifications

- **Blockchain**: Stacks Layer-1
- **Smart Contract Language**: Clarity
- **Minimum Stream**: 1 STX
- **Maximum Duration**: ~1 year (525,600 blocks)
- **Payment Frequency**: Per block (~10 minutes)

## 📋 Core Functions

### For Supporters
- `create-stream`: Start a new payment stream to a creator
- `cancel-stream`: Cancel an active stream and recover remaining funds

### For Creators
- `withdraw-stream`: Withdraw available earnings from streams
- `get-creator-earnings`: View total lifetime earnings

### Read-Only Functions
- `get-stream`: Get detailed information about a specific stream
- `calculate-withdrawable-amount`: Check how much a creator can withdraw
- `get-user-stream-count`: Get number of streams created by a user

## 🚀 Getting Started

### Prerequisites
- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet with STX tokens

### Installation
```bash
git clone <repository-url>
cd streamvault
clarinet check
```

### Usage Example
```clarity
;; Create a 1000 STX stream over 1440 blocks (~10 days)
(contract-call? .streamvault create-stream 'SP1EXAMPLE... u1000000000 u1440)

;; Creator withdraws available funds
(contract-call? .streamvault withdraw-stream u1)
```

## 🔒 Security Features

- **Access Control**: Only authorized users can perform sensitive operations
- **Balance Validation**: Ensures sufficient funds before creating streams
- **Overflow Protection**: Safe arithmetic operations throughout
- **Stream State Management**: Prevents double-spending and invalid operations

## 💡 Use Cases

- **Content Creators**: YouTubers, bloggers, artists receiving ongoing support
- **Open Source**: Developers getting funded for continuous contributions
- **Education**: Students supporting teachers or mentors
- **Charity**: Ongoing donations to causes and organizations

## 🏗️ Architecture

The contract uses a mapping-based architecture to track:
- Stream metadata and status
- User participation counts
- Creator earnings history
- Platform configuration

## 📊 Economics

- **Platform Fee**: 2.5% of withdrawn amounts (configurable)
- **Gas Efficiency**: Optimized for minimal transaction costs
- **Scalability**: Supports unlimited concurrent streams

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run `clarinet check` to ensure validity
5. Submit a pull request
