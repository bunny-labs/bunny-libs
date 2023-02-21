// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "forge-std/Test.sol";

import "../src/MembershipToken/MembershipToken.sol";

contract MockMembership is MembershipToken {
    constructor(string memory name, string memory symbol, Membership[] memory memberships) {
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

    uint256 defaultTotalWeights;
    MembershipToken.Membership[] defaultMembers;

    function setUp() public {
        uint256 defaultMemberCount = 42;
        for (uint256 i; i < defaultMemberCount; i++) {
            uint32 weight = 1000 + uint32(uint256(keccak256(abi.encodePacked(defaultMemberCount, i))) % 9000);
            defaultMembers.push(MembershipToken.Membership(makeAddr(Strings.toString(uint256(i))), weight));
            defaultTotalWeights += weight;
        }
    }

    function testCanInitialize(string memory name, string memory symbol) public {
        MockMembership token = new MockMembership(name, symbol, defaultMembers);

        assertEq(token.name(), name);
        assertEq(token.symbol(), symbol);
        assertEq(token.totalSupply(), defaultMembers.length);
        assertEq(token.totalWeights(), defaultTotalWeights);
    }

    function testCanMintIndividualMemberships(address to, uint32 weight) public {
        vm.assume(to != address(0));

        MockMembership token = new MockMembership(
            "VCooors",
            "VCOOOR",
            noMembers
        );

        assertEq(token.balanceOf(to), 0);
        assertEq(token.totalSupply(), 0);
        assertEq(token.totalWeights(), 0);

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

    function testCanMintMembershipsBatches() public {
        MockMembership token = new MockMembership(
            "VCooors",
            "VCOOOR",
            noMembers
        );
        token.mintMemberships(defaultMembers);

        assertEq(token.totalWeights(), defaultTotalWeights);
        assertEq(token.totalSupply(), defaultMembers.length);
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

            assertEq(token.tokenShare(i, uint224(token.totalSupply()) * maxShares), maxShares);
        }

        assertEq(token.totalSupply(), maxMemberships);
        assertEq(token.totalWeights(), uint48(maxShares) * uint48(maxMemberships));

        address extraMember = makeAddr(vm.toString(maxMemberships));
        vm.expectRevert();
        token.mintMembership(MembershipToken.Membership(extraMember, maxShares));
    }

    function testCanCalculateProportionalShares() public {
        MockMembership token = new MockMembership(
            "VCooors",
            "VCOOOR",
            defaultMembers
        );

        for (uint256 i; i < defaultMembers.length; i++) {
            assertEq(token.tokenShare(i, uint224(defaultTotalWeights)), defaultMembers[i].weight);
        }
    }

    function testCanCalculateMaxShares() public {
        MembershipToken.Membership[] memory members = new MembershipToken.Membership[](1);
        members[0] = MembershipToken.Membership(makeAddr("0"), type(uint32).max);

        MockMembership token = new MockMembership("Vcooors", "VCOOOR", members);

        assertEq(token.tokenShare(0, type(uint224).max), type(uint224).max);
    }

    function testCanGenerateTokenImages() public {
        MockMembership token = new MockMembership(
            "VCooors",
            "VCOOOR",
            defaultMembers
        );

        for (uint256 i; i < defaultMembers.length; i++) {
            vm.writeFile(string(abi.encodePacked("./test/output/", vm.toString(i), ".svg")), token.tokenImage(i));
        }

        vm.expectRevert(MembershipToken.TokenDoesNotExist.selector);
        token.tokenImage(defaultMembers.length);
    }

    function testCanGenerateTokenMetadata() public {
        MockMembership token = new MockMembership(
            "VCooors",
            "VCOOOR",
            defaultMembers
        );

        for (uint256 i; i < defaultMembers.length; i++) {
            token.tokenMetadata(i);
        }

        vm.expectRevert(MembershipToken.TokenDoesNotExist.selector);
        token.tokenMetadata(defaultMembers.length);
    }

    function testCanGenerateTokenUris() public {
        MockMembership token = new MockMembership(
            "VCooors",
            "VCOOOR",
            defaultMembers
        );

        for (uint256 i; i < defaultMembers.length; i++) {
            token.tokenURI(i);
        }

        vm.expectRevert(MembershipToken.TokenDoesNotExist.selector);
        token.tokenURI(defaultMembers.length);
    }
}
