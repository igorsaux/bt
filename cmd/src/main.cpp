//-----------------------------------------------------------------------------
// Copyright 2024 Igor Spichkin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//-----------------------------------------------------------------------------

#include "bt/bt.hpp"
#include "socket.hpp"
#include "socket_buffer.hpp"
#include <algorithm>
#include <array>
#include <format>
#include <iostream>
#include <string>
#include <vector>

struct Args final
{
    std::string mAddr;
    std::string mMessage;
};

void PrintHelp() noexcept
{
    std::cout << "Usage: bt <NODE>:<PORT> <MESSAGE>\nExample: bt "
                 "127.0.0.1:8080 ?ping\n";
}

[[nodiscard]] Args ParseArgs( const int argc, const char* argv[] ) noexcept
{
    Args args{};

    if ( argc < 3 )
    {
        std::cout << "Invalid command: an address with a message required\n";

        PrintHelp();

        std::exit( -1 );
    }

    args.mAddr = std::string{ argv[1] };
    args.mMessage = std::string{ argv[2] };

    if ( argc == 3 )
    {
        return args;
    }

    std::vector<std::string> options;
    options.reserve( argc - 3 );

    for ( size_t i = 3; i < argc; i++ )
    {
        options.emplace_back( argv[i] );
    }

    for ( const auto& arg : options )
    {

        std::cout << std::format( "Unknown argument: {}\n", arg );

        PrintHelp();

        std::exit( -1 );
    }

    return args;
}

struct AddressPair final
{
    std::string mNode;
    std::string mPort;
};

AddressPair ParseAddress( const std::string& address ) noexcept
{
    std::string node;
    std::string port;

    {
        const auto del = address.find_last_of( ':' );

        if ( del == std::string::npos )
        {
            std::cout << std::format( "Invalid address: {}\n", address );

            std::exit( -1 );
        }

        node = address.substr( 0, del );
        port = address.substr( del + 1 );
    }

    return AddressPair{ .mNode = std::move( node ),
                        .mPort = std::move( port ) };
}

int main( const int argc, const char* argv[] )
{
    const auto args = ParseArgs( argc, argv );
    const auto wsa = btcmd::CWSAGuard::Create();

    std::vector<char> encodedMessage;

    {
        bt::EResult result;

        std::tie( result, encodedMessage ) = bt::encode( args.mMessage );

        if ( result != bt::EResult::Ok )
        {
            switch ( result )
            {
            case bt::EResult::DataTooLong:
                std::cout << "Fail to encode the message: data is too long\n";
            default:
                return -1;
            }
        }
    }

    auto [node, port] = ParseAddress( args.mAddr );
    auto socket = btcmd::CreateSocket( node, port );

    socket->Connect();
    socket->Send( encodedMessage );

    btcmd::CSocketBuffer socketBuffer{ std::move( socket ) };

    std::array<char, 2> magic;

    if ( !socketBuffer.Read( magic ) )
    {
        std::cout << "Unexpected eof\n";

        return -1;
    }

    if ( magic[0] != 0x0 || static_cast<uint8_t>( magic[1] ) != 0x83 )
    {
        std::cout << "Invalid magic\n";

        return -1;
    }

    std::array<char, 2> dataSizeBytes;

    if ( !socketBuffer.Read( dataSizeBytes ) )
    {
        std::cout << "Unexpected eof\n";

        return -1;
    }

    uint16_t dataSize = 0;

    if constexpr ( std::endian::native == std::endian::little )
    {
        dataSize |= static_cast<uint8_t>( dataSizeBytes[0] ) << 8;
        dataSize |= static_cast<uint8_t>( dataSizeBytes[1] );
    }
    else
    {
        memcpy( &dataSize, dataSizeBytes.data(), sizeof( uint16_t ) );
    }

    dataSize -= 2;

    char dataType;

    if ( !socketBuffer.Read( &dataType, 1 ) )
    {
        std::cout << "Unexpected eof\n";

        return -1;
    }

    // String
    if ( dataType == 0x06 )
    {
        std::string result;
        result.resize( dataSize, '\0' );

        if ( !socketBuffer.Read( result.data(), dataSize ) )
        {
            std::cout << "Unexpected eof\n";

            return -1;
        }

        std::cout << result << std::endl;
    }
    // Float
    else if ( dataType == 0x2A )
    {
        std::array<char, 4> floatBytes;

        if ( !socketBuffer.Read( floatBytes ) )
        {
            std::cout << "Unexpected eof\n";

            return -1;
        }

        float result = 0;

        if constexpr ( std::endian::native == std::endian::little )
        {
            memcpy( &result, floatBytes.data(), floatBytes.size() );
        }
        else
        {
            std::array<char, 4> revFloatBytes;
            std::ranges::reverse_copy( floatBytes, revFloatBytes.begin() );

            memcpy( &result, revFloatBytes.data(), revFloatBytes.size() );
        }

        std::cout << result << std::endl;
    }
    // Null
    else if ( dataType == 0x00 )
    {
        std::cout << "NULL\n";
    }
    else
    {
        std::cout << std::format( "Unsupported type: 0x{:0>2X}\n", dataType );

        return -1;
    }

    return 0;
}
