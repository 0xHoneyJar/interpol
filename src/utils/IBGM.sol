pragma solidity ^0.8.23;

interface IBGM {
  	function depositFor(address[] calldata vaults, address to) external;
	function contribute(uint256 amount) external;
	function redeem(uint256 amount) external;
	function delegate(bytes calldata validator, uint128 amount) external;
	function unbondQueue(bytes calldata validator, uint256 amount) external;
	function unbond(bytes calldata validator) external;
	function cancel(bytes calldata validator, uint128 amount) external;
	function cancelUnbond(bytes calldata validator, uint128 amount) external;
}