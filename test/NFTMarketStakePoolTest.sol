// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {NFTMarketStakePool} from "../src/NFTMarketStakePool.sol";
import {NFTMarket} from "../src/NFTMarket.sol";
import {PayToken} from "../src/PayToken.sol";
import {MyNFTToken} from "../src/MyNFTToken.sol";

contract NFTMarketStakePoolTest is Test {
    PayToken public payToken;
    MyNFTToken public nft;
    NFTMarket internal nftmarket;
    NFTMarketStakePool public stakePool;

    Account owner = makeAccount("owner");
    Account alice = makeAccount("alice");
    Account bob = makeAccount("bob");
    Account bob2 = makeAccount("bob2");
    Account carol = makeAccount("carol");
    Account dave = makeAccount("dave");
    Account eve = makeAccount("eve");

    uint256 tokenId = 0;
    uint256 price = 1e18;
    uint256 deadline = block.timestamp + 1000;
    bytes32 orderId;

    function setUp() public {
        payToken = new PayToken(owner.addr);
        nft = new MyNFTToken(owner.addr);
        nftmarket = new NFTMarket();
        stakePool = new NFTMarketStakePool(address(nftmarket));

        vm.startPrank(owner.addr); // 默认是测试合约
        vm.label(owner.addr, "ERC20owner");
        payToken.mint(owner.addr, 100e18);

        nft.safeMint(owner.addr, "https://ipfs.io/ipfs/QmSsYRx3LpDAb1GZQm7zZ1AuHZjfbPkD6J7s9r41xu1mf8");
        vm.stopPrank();
    }

    function testTokenBalance() public view {
        assertEq(payToken.balanceOf(owner.addr), 100e18, "owner balance is not 100e18");
        assertEq(payToken.balanceOf(address(nftmarket)), 0, "market balance is not 0");
    }

    function testNFTBalance() public view {
        assertEq(nft.balanceOf(owner.addr), 1, "owner nft balance is not 1");
        assertEq(nft.ownerOf(0), owner.addr, "owner nft is not owner");
    }

    function testTransferToken() public {
        vm.prank(owner.addr);
        payToken.transfer(alice.addr, 10e18);
        assertEq(payToken.balanceOf(alice.addr), 10e18);
        assertEq(payToken.balanceOf(owner.addr), 90e18);
    }

    // 账户 owner 在 ERC721 合约上调用 setApprovalForAll 授权 NFTMarket 合约，参数为 NFTMarket 合约地址和 true
    function testSetApprovalForAll() public {
        vm.prank(owner.addr);
        nft.setApprovalForAll(address(nftmarket), true);
        assertEq(nft.isApprovedForAll(owner.addr, address(nftmarket)), true);
    }

    function testListNFT() public {
        vm.startPrank(owner.addr);
        nft.setApprovalForAll(address(nftmarket), true);
        assertEq(nft.isApprovedForAll(owner.addr, address(nftmarket)), true);
        assertEq(nft.ownerOf(tokenId), owner.addr, "owner nft is not owner");

        // Check emitted event
        vm.expectEmit(true, true, false, false);
        emit NFTMarket.List(address(nft), tokenId, orderId, owner.addr, address(payToken), price, deadline);
        nftmarket.list(address(nft), tokenId, address(payToken), price, deadline);

        // Compute expected orderId
        NFTMarket.SellOrder memory order = NFTMarket.SellOrder({
            seller: owner.addr,
            nft: address(nft),
            tokenId: tokenId,
            payToken: address(payToken),
            price: price,
            deadline: deadline
        });
        bytes32 newOrderId = keccak256(abi.encode(order));

        orderId = nftmarket.listing(address(nft), tokenId);
        assertEq(orderId, newOrderId, "order id is not new order id");
        console.log("orderId: ");
        console.logBytes32(orderId);
        // Check listingOrders mapping
        NFTMarket.SellOrder memory listedOrder = nftmarket.getListingOrders(orderId);
        assertEq(listedOrder.seller, owner.addr);
        assertEq(listedOrder.nft, address(nft));
        assertEq(listedOrder.tokenId, tokenId);
        assertEq(listedOrder.payToken, address(payToken));
        assertEq(listedOrder.price, price);
        assertEq(listedOrder.deadline, deadline);
        assertEq(nft.getApproved(tokenId), address(0), "NFT not approved correctly");

        vm.stopPrank();
    }

    function testBuyNFT() public {
        vm.startPrank(owner.addr);
        nft.approve(address(nftmarket), tokenId);
        nftmarket.list(address(nft), tokenId, address(0), price, deadline);
        orderId = nftmarket.listing(address(nft), tokenId);
        vm.stopPrank();
        nftmarket.setFeeTo(address(stakePool));
        vm.startPrank(alice.addr);
        vm.deal(alice.addr, 1 ether);
        nftmarket.buy{value: 1 ether}(orderId);
        assertEq(nft.ownerOf(tokenId), alice.addr);
        assertEq(address(stakePool).balance, 0.003 ether);
        vm.stopPrank();
    }

    function testStake() public {
        vm.prank(alice.addr);
        vm.deal(alice.addr, 1 ether);
        stakePool.stake{value: 1 ether}();

        NFTMarketStakePool.UserStakeInfo memory userStake = stakePool.getStakes(alice.addr);
        assertEq(userStake.amount, 1 ether);
        assertEq(userStake.rewards, 0); // Assuming rewards should be 0 after initial staking
        assertEq(userStake.index, 0);
        assertEq(stakePool.totalStaked(), 1 ether);
    }

    function testUnstake() public {
        vm.startPrank(alice.addr);
        vm.deal(alice.addr, 1 ether);
        stakePool.stake{value: 1 ether}();
        uint256 balanceBefore = alice.addr.balance;
        stakePool.unstake(0.5 ether);
        vm.stopPrank();

        NFTMarketStakePool.UserStakeInfo memory userStake = stakePool.getStakes(alice.addr);
        assertEq(userStake.amount, 0.5 ether);
        assertEq(userStake.index, 0);
        assertEq(userStake.rewards, 0);
        assertEq(stakePool.totalStaked(), 0.5 ether);
        assertEq(alice.addr.balance, balanceBefore + 0.5 ether);
    }

    function testClaimReward() public {
        // Alice stakes 1 ETH
        vm.startPrank(alice.addr);
        vm.deal(alice.addr, 1 ether);
        stakePool.stake{value: 1 ether}();
        assertEq(stakePool.totalStaked(), 1 ether);
        assertEq(address(stakePool).balance, 1 ether);
        vm.stopPrank();
        _buyNFT();

        uint256 balanceBefore = alice.addr.balance;
        assertEq(balanceBefore, 0 ether);
        vm.prank(alice.addr);
        stakePool.claim();

        assertEq(alice.addr.balance - balanceBefore, 0.003 ether);
        NFTMarketStakePool.UserStakeInfo memory userStake = stakePool.getStakes(alice.addr);
        assertEq(userStake.amount, 1 ether);
        assertEq(userStake.index, 0.003 ether);
        assertEq(userStake.rewards, 0);
        assertEq(stakePool.poolIndex(), 0.003 ether);
        assertEq(stakePool.totalStaked(), 1 ether);
    }

    function testMultipleStakePool() public {
        // 1. alice staked 1 ether
        vm.startPrank(alice.addr);
        vm.deal(alice.addr, 1 ether);
        stakePool.stake{value: 1 ether}();
        assertEq(stakePool.totalStaked(), 1 ether);
        assertEq(address(stakePool).balance, 1 ether);

        NFTMarketStakePool.UserStakeInfo memory aliceStake = stakePool.getStakes(alice.addr);
        assertEq(aliceStake.amount, 1 ether);
        assertEq(aliceStake.index, 0 ether);
        assertEq(aliceStake.rewards, 0);
        vm.stopPrank();
        // 2. buy nft 1 ether generated fee 0.003 ether
        _buyNFT();

        // 3. bob staked 1 ether total staked 2 ether
        vm.startPrank(bob.addr);
        vm.deal(bob.addr, 1 ether);
        stakePool.stake{value: 1 ether}();
        assertEq(stakePool.totalStaked(), 2 ether);
        assertEq(address(stakePool).balance, 2.003 ether);

        NFTMarketStakePool.UserStakeInfo memory bobStake = stakePool.getStakes(bob.addr);
        assertEq(bobStake.amount, 1 ether);
        // 1e18 * 0.003 * 1e18 / 1e18 = 0.003 ether  3e15 - 0.003e18 = 0
        assertEq(bobStake.index, 0.003 ether);
        assertEq(bobStake.rewards, 0 ether);
        assertEq(stakePool.poolIndex(), 0.003 ether);
        vm.stopPrank();

        // 4. carol staked 1 ether total staked 3 ether
        vm.startPrank(carol.addr);
        vm.deal(carol.addr, 1 ether);
        stakePool.stake{value: 1 ether}();
        assertEq(stakePool.totalStaked(), 3 ether);
        assertEq(address(stakePool).balance, 3.003 ether);
        vm.stopPrank();

        assertEq(stakePool.poolIndex(), 0.003 ether);

        // 5. dave staked 1 ether total staked 4 ether
        vm.startPrank(dave.addr);
        vm.deal(dave.addr, 1 ether);
        stakePool.stake{value: 1 ether}();
        assertEq(stakePool.totalStaked(), 4 ether);
        assertEq(address(stakePool).balance, 4.003 ether);

        vm.stopPrank();

        // 6. alice buy nft 1 ether generated fee 0.003 ether total fee 0.006 ether
        vm.startPrank(owner.addr);
        nft.approve(address(nftmarket), tokenId);
        nftmarket.list(address(nft), tokenId, address(0), price, deadline);
        orderId = nftmarket.listing(address(nft), tokenId);
        vm.stopPrank();

        assertEq(stakePool.poolIndex(), 0.003 ether);

        vm.startPrank(alice.addr);
        vm.deal(alice.addr, 1 ether);
        nftmarket.buy{value: 1 ether}(orderId);
        assertEq(nft.ownerOf(tokenId), alice.addr);
        assertEq(address(stakePool).balance, 4.006 ether);
        // 0.003e18 + 0.003e18 * 1e18 / 4e18 = 3.75e15 = 0.00375 ether
        assertEq(stakePool.poolIndex(), 0.00375 ether);
        vm.stopPrank();

        // 7. eve staked 1 ether total staked 5 ether
        vm.startPrank(eve.addr);
        vm.deal(eve.addr, 1 ether);
        stakePool.stake{value: 1 ether}();
        assertEq(stakePool.totalStaked(), 5 ether);
        assertEq(address(stakePool).balance, 5.006 ether);
        vm.stopPrank();
        assertEq(stakePool.poolIndex(), 0.00375 ether);

        // 8. owner list nft
        vm.startPrank(owner.addr);
        nft.safeMint(owner.addr, "https://ipfs.io/ipfs/QmSsYRx3LpDAb1GZQm7zZ1AuHZjfbPkD6J7s9r41xu1mf8");
        nft.approve(address(nftmarket), 2);
        nftmarket.list(address(nft), 2, address(0), price, deadline);
        orderId = nftmarket.listing(address(nft), 2);
        vm.stopPrank();
        // 9. alice buy nft 1 ether generation fee 0.003 ether total fee 0.009 ether
        vm.startPrank(alice.addr);
        vm.deal(alice.addr, 1 ether);
        nftmarket.buy{value: 1 ether}(orderId);
        assertEq(nft.ownerOf(2), alice.addr);
        assertEq(address(stakePool).balance, 5.009 ether);
        vm.stopPrank();

        // 0.00375e18 + 0.003e18 * 1e18 / 5e18 = 4.35e15 = 0.00435 ether
        assertEq(stakePool.poolIndex(), 0.00435 ether);
        uint256 balanceBefore = alice.addr.balance;
        assertEq(balanceBefore, 0 ether);

        NFTMarketStakePool.UserStakeInfo memory aliceUserStake = stakePool.getStakes(alice.addr);
        assertEq(aliceUserStake.amount, 1 ether);
        assertEq(aliceUserStake.index, 0 ether);
        assertEq(aliceUserStake.rewards, 0);

        vm.prank(alice.addr);
        stakePool.claim();
        // (1e18 * (0.00435e18 - 0)) / 1e18 = 4.35e15 = 0.00435e18 = 0.00435 ether
        assertEq(alice.addr.balance - balanceBefore, 0.00435 ether);
        NFTMarketStakePool.UserStakeInfo memory userStake = stakePool.getStakes(alice.addr);
        assertEq(userStake.amount, 1 ether);
        assertEq(userStake.index, 0.00435 ether);
        assertEq(userStake.rewards, 0);
        assertEq(stakePool.poolIndex(), 0.00435 ether);
        assertEq(stakePool.totalStaked(), 5 ether);
        // 0.009 - 0.00435 = 0.00465 ether
        assertEq(stakePool.totalRewards(), 0.00465 ether);
    }

    function _buyNFT() public {
        uint256 bobTokenId = 1;
        vm.startPrank(owner.addr);
        nft.safeMint(bob.addr, "https://ipfs.io/ipfs/QmSsYRx3LpDAb1GZQm7zZ1AuHZjfbPkD6J7s9r41xu1mf8");
        vm.stopPrank();

        vm.startPrank(bob.addr);
        assertEq(nft.balanceOf(bob.addr), 1, "owner nft balance is not 1");
        assertEq(nft.ownerOf(bobTokenId), bob.addr, "owner nft is not bob");
        nft.approve(address(nftmarket), bobTokenId);

        nftmarket.list(address(nft), bobTokenId, address(0), price, deadline);
        orderId = nftmarket.listing(address(nft), bobTokenId);
        vm.stopPrank();

        nftmarket.setFeeTo(address(stakePool));

        vm.startPrank(bob2.addr);
        vm.deal(bob2.addr, 1 ether);
        nftmarket.buy{value: 1 ether}(orderId);

        assertEq(nft.ownerOf(bobTokenId), bob2.addr);
        assertEq(address(stakePool).balance, 1.003 ether);
        vm.stopPrank();
    }
}
