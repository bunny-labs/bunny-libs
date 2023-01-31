// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";

import "../src/MembershipToken/MembershipToken.sol";

contract MockMembership is MembershipToken {
    constructor(
        string memory name,
        string memory symbol,
        Membership[] memory memberships
    ) {
        _initialize(name, symbol, memberships);
    }

    function mintMembership(Membership memory membership) public {
        _mintMembership(membership);
    }

    function mintMemberships(Membership[] memory memberships) public {
        _mintMemberships(memberships);
    }

    function memberOnlyFunction() public memberOnly {}
}

contract MembershipTokenTest is Test {
    MembershipToken.Membership[] noMembers;

    function expand16(uint16 seed, uint256 size)
        public
        pure
        returns (uint16[] memory)
    {
        uint16[] memory numbers = new uint16[](size);
        for (uint256 i; i < size; i++) {
            numbers[i] = uint16(
                uint256(keccak256(abi.encodePacked(seed, i))) % type(uint16).max
            );
        }
        return numbers;
    }

    function setupMembers(uint256 memberCount)
        public
        returns (MembershipToken.Membership[] memory)
    {
        MembershipToken.Membership[]
            memory members = new MembershipToken.Membership[](memberCount);
        uint16[] memory shares = expand16(
            uint16(memberCount % type(uint16).max),
            memberCount
        );

        for (uint256 i; i < memberCount; i++) {
            members[i] = MembershipToken.Membership(
                makeAddr(Strings.toString(uint256(i))),
                shares[i]
            );
        }

        return members;
    }

    function testCanInitialize(string memory name, string memory symbol)
        public
    {
        MockMembership token = new MockMembership(name, symbol, noMembers);

        assertEq(token.name(), name);
        assertEq(token.symbol(), symbol);
        assertEq(token.totalSupply(), 0);
        assertEq(token.totalWeights(), 0);
    }

    function testCanMintMemberships(address to, uint32 weight) public {
        vm.assume(to != address(0));

        MockMembership token = new MockMembership(
            "VCooors",
            "VCOOOR",
            noMembers
        );
        token.mintMembership(MembershipToken.Membership(to, weight));

        assertEq(token.balanceOf(to), 1);
        assertEq(token.totalSupply(), 1);
        assertEq(token.totalWeights(), weight);
        assertEq(token.membershipWeight(token.totalSupply() - 1), weight);
    }

    function testCannotMintMembershipsToNull() public {
        MockMembership token = new MockMembership(
            "VCooors",
            "VCOOOR",
            noMembers
        );

        vm.expectRevert();
        token.mintMembership(MembershipToken.Membership(address(0), 1));
    }

    function testCanBatchMintMemberships(uint8 memberCount) public {
        MembershipToken.Membership[] memory members = setupMembers(memberCount);
        MockMembership token = new MockMembership(
            "VCooors",
            "VCOOOR",
            noMembers
        );
        token.mintMemberships(members);

        uint48 totalWeights;
        for (uint256 i; i < memberCount; i++) {
            assertEq(token.membershipWeight(i), members[i].weight);
            totalWeights += members[i].weight;
        }

        assertEq(token.totalWeights(), totalWeights);
        assertEq(token.totalSupply(), memberCount);
    }

    function testWillAllowMemberOnlyAccess() public {
        MockMembership token = new MockMembership(
            "VCooors",
            "VCOOOR",
            noMembers
        );

        address nonMember = makeAddr("nonMember");
        address member = makeAddr("member");
        token.mintMembership(MembershipToken.Membership(member, 1));

        vm.prank(member);
        token.memberOnlyFunction();

        vm.expectRevert(MembershipToken.NotAMember.selector);
        vm.prank(nonMember);
        token.memberOnlyFunction();
    }

    function testCannotMintMoreThanMaximumMemberships() public {
        MockMembership token = new MockMembership(
            "VCooors",
            "VCOOOR",
            noMembers
        );

        uint32 maxShares = type(uint32).max;
        uint16 maxMemberships = type(uint16).max;

        for (uint16 i; i < maxMemberships; i++) {
            address member = makeAddr(vm.toString(i));
            token.mintMembership(MembershipToken.Membership(member, maxShares));

            assertEq(
                token.tokenShare(i, uint224(i + 1) * maxShares),
                maxShares
            );
        }

        assertEq(token.totalSupply(), maxMemberships);
        assertEq(
            token.totalWeights(),
            uint48(maxShares) * uint48(maxMemberships)
        );

        address extraMember = makeAddr(vm.toString(maxMemberships));
        vm.expectRevert();
        token.mintMembership(
            MembershipToken.Membership(extraMember, maxShares)
        );
    }

    function testCanCalculateProportionalShares(uint8 memberCount) public {
        vm.assume(memberCount > 0);

        MembershipToken.Membership[] memory memberships = setupMembers(
            memberCount
        );
        MockMembership token = new MockMembership(
            "VCooors",
            "VCOOOR",
            memberships
        );

        uint256 totalWeights = token.totalWeights();
        for (uint256 i; i < memberCount; i++) {
            assertEq(
                token.tokenShare(i, uint224(totalWeights)),
                memberships[i].weight
            );
        }
    }

    function testCanCalculateMaxShares() public {
        MembershipToken.Membership[]
            memory members = new MembershipToken.Membership[](1);
        members[0] = MembershipToken.Membership(
            makeAddr("0"),
            type(uint32).max
        );

        MockMembership token = new MockMembership("Vcooors", "VCOOOR", members);

        assertEq(token.tokenShare(0, type(uint224).max), type(uint224).max);
    }

    function testCanGenerateTokenImages(uint8 memberCount) public {
        vm.assume(memberCount > 0);

        MockMembership token = new MockMembership(
            "VCooors",
            "VCOOOR",
            setupMembers(memberCount)
        );

        for (uint256 i; i < memberCount; i++) {
            token.tokenImage(i);
        }

        vm.expectRevert(MembershipToken.TokenDoesNotExist.selector);
        token.tokenImage(memberCount);
    }

    function testCanGenerateTokenMetadata(uint8 memberCount) public {
        vm.assume(memberCount > 0);

        MockMembership token = new MockMembership(
            "VCooors",
            "VCOOOR",
            setupMembers(memberCount)
        );

        for (uint256 i; i < memberCount; i++) {
            token.tokenMetadata(i);
        }

        vm.expectRevert(MembershipToken.TokenDoesNotExist.selector);
        token.tokenMetadata(memberCount);
    }

    function testCanGenerateTokenUris(uint8 memberCount) public {
        vm.assume(memberCount > 0);

        MockMembership token = new MockMembership(
            "VCooors",
            "VCOOOR",
            setupMembers(memberCount)
        );

        for (uint256 i; i < memberCount; i++) {
            token.tokenURI(i);
        }

        vm.expectRevert(MembershipToken.TokenDoesNotExist.selector);
        token.tokenURI(memberCount);
    }
}
